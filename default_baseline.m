
%% ========================================================================
%  ONION E. COLI CONTAMINATION MODEL
%  ========================================================================
%  Models E.coli contamination from wildlife fecal + irrigation water
%  onto a 1-acre Vidalia onion field. Jul-Jun fiscal year.


clc; clear; rng(1);

%% ========================================================================
%  SECTION 1: INITIALIZATION & FIELD PARAMETERS
%% ========================================================================
fprintf('\n========= ONION E. COLI CONTAMINATION MODEL ==========\n');
fprintf('Initializing parameters...\n');

iterations = 1000; % bump to 1000 for real MC runs

% crop timing - planting Nov-Dec, harvest Feb-Apr
% day counts are relative to Jul 1 start
plant1 = unidrnd(61, iterations, 1) + 123;  % Nov-Dec window
growth_days = unidrnd(31, iterations, 1) + 89;  % 90-120 days
har1 = plant1 + growth_days;  % can exceed 365, thats fine

fprintf('  Planting range: Day %d to %d\n', min(plant1), max(plant1));
fprintf('  Growth period: %d to %d days\n', min(growth_days), max(growth_days));
fprintf('  Harvest range: Day %d to %d\n', min(har1), max(har1));
fprintf('  Harvests in next year: %d (%.1f%%)\n', ...
        sum(har1 > 365), sum(har1 > 365) / iterations * 100);

% field geometry - 1 acre, square assumption
plantnum = 58080;
acre_m2 = 4046.8564224;
area_per_plant = acre_m2 / plantnum; % ~0.0691 m^2/plant
subplot_area_m2 = area_per_plant;
num_subplots = plantnum;
plants_per_subplot = 1;
subplot_assignment = 1:plantnum;  % 1:1 mapping

fprintf('  Area per plant: %.4f m\xc2\xb2 (subplot size)\n', area_per_plant);
fprintf('  Total subplots: %d\n', num_subplots);

% irrigation params (depth inches per event; ival = days between events)
depth.Establish = 0.50;
depth.Veg = 0.50;
% Bulbing stage water volume: PERT(min, mode, max) inches per event
depth.BulbMin  = 0.50;
depth.BulbMode = 0.60;
depth.BulbMax  = 1.00;
depth.BulbLam  = 4;
bulb_a1 = 1 + depth.BulbLam * (depth.BulbMode - depth.BulbMin) / (depth.BulbMax - depth.BulbMin);
bulb_a2 = 1 + depth.BulbLam * (depth.BulbMax - depth.BulbMode) / (depth.BulbMax - depth.BulbMin);
depth.BulbBeta = makedist('Beta', 'a', bulb_a1, 'b', bulb_a2);
ival.Establish = 7;
ival.Veg = 7;
ival.Bulb = 3;
fprintf('  Irrigation depth: Establish=%.2f in/%d d; Veg=%.2f in/%d d; Bulb=PERT(%.2f,%.2f,%.2f) in/%d d\n', ...
    depth.Establish, ival.Establish, depth.Veg, ival.Veg, ...
    depth.BulbMin, depth.BulbMode, depth.BulbMax, ival.Bulb);
irrigation_volume_factor = 1.00;  % align with Updated_Baseline.m (1.00 / 0.75 / 0.50)
if ~ismember(irrigation_volume_factor, [1.00, 0.75, 0.50])
    error('irrigation_volume_factor must be 1.00, 0.75, or 0.50');
end
bulb_start = 55; % Days after planting (DAP)
irr_stop = 14; % pre-harvest dry-down

K = 254 * area_per_plant; % 1 in water = 25.4 L/m^2

% Racine et al. prevalence (TODO: rename this var)
prev_min = [78.40, 15.27, 0.464]; 


% curing decay distributions - fitted from field MPN data
% all in log10 MPN space
curing_dist_day0 = makedist('Normal', 'mu', 0.7730, 'sigma', 0.3532);  % day 0
curing_dist_day1 = makedist('Normal', 'mu', 0.6689, 'sigma', 0.4027);  % day 1
curing_dist_day7 = makedist('Normal', 'mu', 0.8337, 'sigma', 0.3997);  % day 7
%curing_dist_day28 = makedist('Normal', 'mu', -5.0000, 'sigma', 0.6079); % day 28 (basically zero)
curing_dist_day28 = 0

curing_time_points = [0, 1, 7, 28];

% pre-compute linear decay slope for each iteration
% sample 4 MPN points, fit a line through them
curing_slope = zeros(iterations, 1);
curing_intercept = zeros(iterations, 1);
curing_sampled_mpn = zeros(iterations, 4);

fprintf('\nPre-computing curing decay rates for %d iterations...\n', iterations);

for i = 1:iterations
    mpn_day0  = random(curing_dist_day0, 1);
    mpn_day1  = random(curing_dist_day1, 1);
    mpn_day7  = random(curing_dist_day7, 1);
    mpn_day28 = random(curing_dist_day28, 1);
    
    curing_sampled_mpn(i, :) = [mpn_day0, mpn_day1, mpn_day7, mpn_day28];
    
    p = polyfit(curing_time_points, [mpn_day0, mpn_day1, mpn_day7, mpn_day28], 1);
    curing_slope(i) = p(1);      % should be negative (decay)
    curing_intercept(i) = p(2);   % y-intercept
end

fprintf('  Curing decay slopes: mean=%.4f, std=%.4f\n', mean(curing_slope), std(curing_slope));
fprintf('  Curing intercepts:   mean=%.4f, std=%.4f\n', mean(curing_intercept), std(curing_intercept));
fprintf('  Slope range: [%.4f, %.4f]\n', min(curing_slope), max(curing_slope));

% quick plot of example fits
figure(15); clf;
n_examples = min(10, iterations);
hold on;
day_range = linspace(0, 28, 100);
for i = 1:n_examples
    plot(curing_time_points, curing_sampled_mpn(i,:), 'o', 'MarkerSize', 6);
    fitted_mpn = max(0, curing_intercept(i) + curing_slope(i) * day_range);
    plot(day_range, fitted_mpn, '-', 'LineWidth', 1);
end
hold off;
xlabel('Days of Field Curing', 'FontSize', 12);
ylabel('Log MPN/onion bulb', 'FontSize', 12);
title('Stochastic Linear Decay Fits (Sample Iterations)', ...
      'FontSize', 13, 'FontWeight', 'bold');
grid on;
fprintf('  Figure 15 created: Example curing decay fits\n');


% monthly soil decay rates (log10CFU/day) - from 10 year from 2016-2025 weather data
% reordered to Jul->Jun
monthly_decay = [-0.079533333,-0.073033333,-0.079533333,-0.0793,-0.0793,-0.079533333, -0.079533333,-0.079533333,-0.0793,-0.079533333,-0.073033333, -0.073033333];

% rainfall (in, Vidalia) - also Jul->Jun rainfall_monthly
rainfall_monthly = [2.77, 5.21, 0.15, 0.51, 0.28, 2.36, 1.09,1.91, 3.30, 2.84, 9.78, 7.06];
%temp_daily = interp1(1:12, temp_monthly, linspace(1, 12, 365));
moisture_daily = generate_moisture_profile(365, rainfall_monthly);


fprintf('  Iterations: %d\n', iterations);
fprintf('  Plants: %d\n', plantnum);
fprintf('  Area per plant: %.4f m\xc2\xb2\n', area_per_plant);
%% ========================================================================
%  SECTION 2: WILDLIFE FECAL CONTAMINATION
%% ========================================================================
fprintf('\nGenerating wildlife fecal contamination...\n');

% deer - seasonal fecal weight variation (g/day)
deer_seasonal_weight = [734.0616, 734.0616,1171.5387, 1171.5387, 1171.5387, 1171.5387, ...
                        440.7372, 440.7372, 440.7372, 440.7372, 425.25, 425.25];

pd = makedist('lognormal', 5.95, 0.90);   % E.coli conc in feces
td = makedist('Triangular', 'a', 0.012, 'b', (0.012+0.06)/2, 'c', 0.06);  % density per ha

CFU_deer = zeros(iterations, 12);
for month = 1:12
    cont_feral = random(pd, iterations, 1); 
    pop_dens = random(td, iterations, 1);
    amt_fecal = deer_seasonal_weight(month) * pop_dens;
    CFU_deer(:, month) = amt_fecal .* cont_feral;
end

% wild pig - constant 1121 g/day year round
wild_pig_seasonal_weight = [1121, 1121, 1121, 1121, 1121, 1121, ...
                            1121, 1121, 1121, 1121, 1121, 1121];

pd_pig = makedist('lognormal', 7.510, 1.056);
td_pig = makedist('Triangular', 'a', 0.003397, 'b', (0.003397+0.022605)/2, 'c', 0.022605);  

CFU_wildpig = zeros(iterations, 12);
for month = 1:12
    cont_wild_pig = random(pd_pig, iterations, 1);
    defec_rate_pig = random(td_pig, iterations, 1);
    amt_wildpig = wild_pig_seasonal_weight(month) * defec_rate_pig;
    CFU_wildpig(:, month) = amt_wildpig .* cont_wild_pig;  
end

% feral pig - same structure, different E.coli distribution
feral_pig_seasonal_weight = [1121, 1121, 1121, 1121, 1121, 1121, ...
                             1121, 1121, 1121, 1121, 1121, 1121];

pd_feral_pig = makedist('lognormal', 3.945, 1.528);
td_feral_pig = makedist('Triangular', 'a', 0.00290325, 'b', (0.00290325+0.022605613)/2, 'c', 0.022605613);  

CFU_feral_pig = zeros(iterations, 12);
for month = 1:12
    cont_feral_pig = random(pd_feral_pig, iterations, 1);
    defec_rate_feral_pig = random(td_feral_pig, iterations, 1);
    amt_feralpig = feral_pig_seasonal_weight(month) * defec_rate_feral_pig;
    CFU_feral_pig(:, month) = amt_feralpig .* cont_feral_pig;
end

fprintf('  Deer fecal: 12 months generated\n');
fprintf('  Wild pig: 12 months generated\n');
fprintf('  Feral pig: 12 months generated\n');

%% ========================================================================
%  SECTION 3: SOIL CONTAMINATION BUILD-UP
%% ========================================================================
fprintf('\nBuilding soil contamination matrix (CFU_soil)...\n');

% main 3D array: [iterations x plants x 365]
CFU_soil = zeros(iterations, plantnum, 365);

%% PART 0: Carryover from previous year (last 3 months)
fprintf('  Part 0: Previous year carryover...\n');
fprintf('  Part 0: Previous year carryover (from June-end distribution)...\n');

june_end_dist = makedist('Lognormal', -0.7282, 0.3465);

for i = 1:iterations
    carryover = random(june_end_dist, 1);
   
    CFU_soil(i, :, 1) = carryover;
end
%% PART 1: Pre-crop accumulation (before planting)
fprintf('  Part 1: Pre-crop 1 accumulation...\n');

for i = 1:iterations
    for k = 1:(plant1(i) - 1)
        day_idx = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        
        month = get_month_index_jul_start(day_idx);

        if month > 12, month = 12; end
        
        daily_input = (CFU_deer(i, month) + CFU_wildpig(i, month) + ...
                       CFU_feral_pig(i, month)) / (plantnum * 30);
        
        CFU_soil(i, :, next_day_idx) = CFU_soil(i, :, day_idx) + daily_input;
        CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, next_day_idx) + 1e-10) +monthly_decay(month));
    end
end
%% PART 2: During crop growth (with year wraparound)
fprintf('  Part 2: During crop 1 (plant-level contamination)...\n');

% pre-generate 20 compliant irrigation water samples per iteration
% lognormal(2.1, 0.4), reject if GM > 126 or STV > 410
irr_dist = makedist('Lognormal', 2.1, 0.4);
n_irr_samples = 20;
GM_limit = 126;
STV_limit = 410;

irr_source_samples = cell(iterations, 1);
irr_GM = zeros(iterations, 1);
irr_STV = zeros(iterations, 1);

fprintf('    Generating compliant water quality sets (20 samples each)...\n');
for i = 1:iterations
    compliant = false;
    n_attempts = 0;
    while ~compliant
        n_attempts = n_attempts + 1;
        C_samples = random(irr_dist, n_irr_samples, 1);
        log10_C = log10(C_samples);
        
        x_bar = mean(log10_C);
        s = std(log10_C);
        GM = 10^x_bar;
        STV = 10^(x_bar + 1.2816 * s);
        
        if GM <= GM_limit && STV <= STV_limit
            compliant = true;
        end
    end
    irr_source_samples{i} = C_samples;
    irr_GM(i) = GM;
    irr_STV(i) = STV;
    
    fprintf('    Iter %d: GM=%.2f, STV=%.2f (accepted after %d draw(s))\n', i, GM, STV, n_attempts);
    fprintf('      20 samples (CFU/100mL): ');
    fprintf('%.1f ', C_samples);
    fprintf('\n');
end

fprintf('    GM range: [%.1f, %.1f] (limit: %d)\n', min(irr_GM), max(irr_GM), GM_limit);
fprintf('    STV range: [%.1f, %.1f] (limit: %d)\n', min(irr_STV), max(irr_STV), STV_limit);

irrigation_schedule_crop1 = cell(iterations, 1);
irrigation_concentrations_crop1 = cell(iterations, 1);

for i = 1:iterations
    irr_events = onion_irrig_days(plant1(i), har1(i), bulb_start, irr_stop, ival);
    irrigation_schedule_crop1{i} = irr_events;
    irr_day_list = [irr_events.doy];
    
    source_cfu_per_event = zeros(length(irr_events), 1);
    
    for k = plant1(i):(har1(i) - 1)
        day_idx = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        
        month = get_month_index_jul_start(day_idx);

        if month > 12, month = 12; end
        
        % distribute wildlife fecal to all plants uniformly
        deer_total_cfu = CFU_deer(i, month);
        wildpig_total_cfu = CFU_wildpig(i, month);
        feralpig_total_cfu = CFU_feral_pig(i, month);
        
        deer_per_plant = distribute_wildlife_to_subplots(deer_total_cfu, plantnum, 'uniform');
        wildpig_per_plant = distribute_wildlife_to_subplots(wildpig_total_cfu, plantnum, 'uniform');
        feralpig_per_plant = distribute_wildlife_to_subplots(feralpig_total_cfu, plantnum, 'uniform');
        
        % monthly -> daily
        deer_daily = deer_per_plant / 30;
        wildpig_daily = wildpig_per_plant / 30;
        feralpig_daily = feralpig_per_plant / 30;
        
        wildlife_cfu_per_plant = deer_daily + wildpig_daily + feralpig_daily;
        CFU_soil(i, :, day_idx) = CFU_soil(i, :, day_idx) + wildlife_cfu_per_plant';
        
        % irrigation water contamination on irrigation days
        if ismember(k, irr_day_list)
            event_idx = find([irr_events.doy] == k, 1);
            stage = irr_events(event_idx).stage;
            
            % source water quality: pull from pre-screened 20 samples + rainfall
            rainfall_amount_mm = rainfall_monthly(month);
            cfu_gain_from_rainfall = calculate_rainfall_cfu_gain(rainfall_amount_mm);
            sample_idx = mod(event_idx - 1, n_irr_samples) + 1;
            source_baseline_cfu = irr_source_samples{i}(sample_idx);
            source_cfu_100ml = source_baseline_cfu + cfu_gain_from_rainfall;
            
            source_cfu_per_event(event_idx) = source_cfu_100ml;  % save for section 4
            
            % how much water hits each plant -> CFU
            irr_depth_in = depth_for_stage(stage, depth) * irrigation_volume_factor;
            water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
            cfu_irrigation_per_plant = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
            
            CFU_soil(i, :, day_idx) = CFU_soil(i, :, day_idx) + cfu_irrigation_per_plant;
        end
        
        % daily decay
        if day_idx < 365
            CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, day_idx) + 1e-10) + monthly_decay(month));
        else
            % wrap 365 -> 1
            CFU_soil(i, :, 1) = 10.^(log10(CFU_soil(i, :, 365) + 1e-10) + monthly_decay(month));
        end
    end
    
    irrigation_concentrations_crop1{i} = source_cfu_per_event;
    
    if mod(i, 50) == 0
        fprintf('    Iteration %d complete\n', i);
    end
end



%% PART 3: Post-harvest ground prep
fprintf('  Part 3: Ground preparation post-crop 1...\n');

for i = 1:iterations
    har_day_idx = mod(har1(i) - 1, 365) + 1;
    
    % tilling mixes everything evenly
    mean_cfu = mean(CFU_soil(i, :, har_day_idx));
    CFU_soil(i, :, har_day_idx) = mean_cfu;
    
    for k = har1(i):365
        day_idx = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        
        month = get_month_index_jul_start(day_idx);

        if month > 12, month = 12; end
        
        daily_input = (CFU_deer(i, month) + CFU_wildpig(i, month) + ...
                       CFU_feral_pig(i, month)) / (plantnum * 30);
        
        if next_day_idx > day_idx
            CFU_soil(i, :, next_day_idx) = CFU_soil(i, :, day_idx) + daily_input;
            CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end
end
%% ========================================================================
%  SECTION 3.5: DAILY SOIL CFU TRACKING
%% ========================================================================
fprintf('\nCreating daily soil CFU tracking matrix...\n');

% collapse 3D -> 2D by averaging across plants
CFU_daily = zeros(iterations, 365);

for i = 1:iterations
    for day = 1:365
        CFU_daily(i, day) = mean(CFU_soil(i, :, day));
    end
end

fprintf('  Daily CFU matrix created: [%d iterations × %d days]\n', iterations, 365);
fprintf('  Mean CFU across all days: %.2e\n', mean(CFU_daily(:)));
fprintf('  Max daily CFU: %.2e (Day %d, Iter %d)\n', ...
        max(CFU_daily(:)), find(CFU_daily == max(CFU_daily(:)), 1));

daily_mean = mean(CFU_daily, 1);
daily_std = std(CFU_daily, 0, 1);
daily_max = max(CFU_daily, [], 1);

fprintf('  Daily statistics calculated\n');




%% ========================================================================
%  SECTION 4: ONION SURFACE CONTAMINATION
%% ========================================================================
fprintf('\n========== ONION SURFACE CONTAMINATION ==========\n');
fprintf('Calculating contamination from irrigation water and soil transfer...\n');

CFU_crop1 = zeros(iterations, plantnum);

% --- pathway 1: irrigation water survival ---
daily_decay_rate = 0.0177;  % log10 reduction per day
survival_multiplier = 0.0177;

fprintf('\nPathway 1: Irrigation Water\n');
fprintf('  Decay model: Linear (k=%.4f/day)\n', daily_decay_rate);
fprintf('  Daily survival multiplier: %.4f\n', survival_multiplier);

% --- pathway 2: soil-to-onion transfer (PERT distribution) ---
pert_min  = 0.0036;
pert_mode = 0.006549;
pert_max  = 0.0585;
lam       = 4;

alpha1 = 1 + lam * (pert_mode - pert_min) / (pert_max - pert_min);
alpha2 = 1 + lam * (pert_max - pert_mode) / (pert_max - pert_min);
beta_dist = makedist('Beta', 'a', alpha1, 'b', alpha2);

fprintf('\nPathway 2: Soil Transfer\n');
fprintf('  Transfer model: PERT(min=%.4f, mode=%.6f, max=%.4f)\n', pert_min, pert_mode, pert_max);
fprintf('  Beta shape params: alpha1=%.4f, alpha2=%.4f\n', alpha1, alpha2);


CFU_onion_survival = zeros(iterations, plantnum);   % pathway 1
CFU_soil_pathway = zeros(iterations, plantnum);      % pathway 2

fprintf('\n--- Processing iterations ---\n');

%% PATHWAY 1: IRRIGATION WATER -> ONION SURFACE
fprintf('\nCalculating Pathway 1: Irrigation water survival...\n');

for i = 1:iterations
    irr_events = irrigation_schedule_crop1{i};
    source_cfu_values = irrigation_concentrations_crop1{i};
    n_events = length(irr_events);
    
    for j = 1:plantnum
        total_cfu = 0;
        
for ev = 1:n_events
    irr_day = irr_events(ev).doy;
    stage = irr_events(ev).stage;

    % only bulbing stage reaches the bulb
    if ~strcmp(stage, 'Bulb')
        continue;
    end

    source_cfu_100ml = source_cfu_values(ev);

    irr_depth_in = depth_for_stage(stage, depth) * irrigation_volume_factor;
    water_volume_L = irr_depth_in * 25.4 * area_per_plant;

    L0_cfu = (source_cfu_100ml / 100) * water_volume_L * 1000;

    % days from this event to harvest
    if har1(i) >= irr_day
        days_elapsed = har1(i) - irr_day;
    else
        days_elapsed = (365 - irr_day) + har1(i);
    end


    if days_elapsed > 0
        log_reduction = daily_decay_rate * days_elapsed;
        CFU_at_harvest = 10^(log10(L0_cfu + 1e-10) - log_reduction);


        transfer_coefficient = pert_min + (pert_max - pert_min) * random(beta_dist, 1);
        transferred_cfu = CFU_at_harvest * transfer_coefficient;

        total_cfu = total_cfu + transferred_cfu;
        
    end
end

        
        CFU_onion_survival(i, j) = total_cfu;
    end
    
    if mod(i, 50) == 0
        fprintf('  Pathway 1: Iteration %d/%d complete\n', i, iterations);
    end
end

% extract end-of-June soil CFU for all iterations
june_end_cfu = CFU_daily(:, 365);

% basic stats
fprintf('\nEnd-of-June Soil CFU Distribution:\n');
fprintf('  Mean: %.4e\n', mean(june_end_cfu));
fprintf('  Median: %.4e\n', median(june_end_cfu));
fprintf('  Std: %.4e\n', std(june_end_cfu));
fprintf('  Min: %.4e, Max: %.4e\n', min(june_end_cfu), max(june_end_cfu));

% fit lognormal in log10 space (since CFU is right-skewed)
log10_vals = log10(june_end_cfu + 1e-10);
mu_fit = mean(log10_vals);
sigma_fit = std(log10_vals);
fprintf('  Fitted log10-Normal: mu=%.4f, sigma=%.4f\n', mu_fit, sigma_fit);

% save for future use as next-year carryover
save('june_end_cfu_distribution.mat', 'june_end_cfu', 'mu_fit', 'sigma_fit');
%% ========================================================================
%  SECTION 4.3: DAILY IRRIGATION PATHWAY TRACKING
%% ========================================================================
fprintf('\nCreating daily irrigation pathway (CFU_onion_survival) tracking matrix...\n');

CFU_irrigation_daily = zeros(iterations, 365);
CFU_irrigation_plant_daily = zeros(iterations, plantnum, 365);

for i = 1:iterations
    irr_events = irrigation_schedule_crop1{i};
    source_cfu_values = irrigation_concentrations_crop1{i};
    n_events = length(irr_events);
    
    for j = 1:plantnum
        for ev = 1:n_events
            irr_day = irr_events(ev).doy;
            stage = irr_events(ev).stage;
            
            if ~strcmp(stage, 'Bulb')
                continue;
            end
            
            source_cfu_100ml = source_cfu_values(ev);
            
            irr_depth_in = depth_for_stage(stage, depth) * irrigation_volume_factor;
            water_volume_L = irr_depth_in * 25.4 * area_per_plant;
            
            L0_cfu = (source_cfu_100ml / 100) * water_volume_L * 1000;
            
            transfer_coefficient = pert_min + (pert_max - pert_min) * random(beta_dist, 1);
            initial_transferred = L0_cfu * transfer_coefficient;
            
            % track decay from irr day through harvest
            if har1(i) >= irr_day
                harvest_day_range = irr_day:har1(i);
            else
                harvest_day_range = [irr_day:365, 1:har1(i)];
            end
            
            current_cfu = initial_transferred;
            for k = 1:length(harvest_day_range)
                actual_day = harvest_day_range(k);
                day_idx = mod(actual_day - 1, 365) + 1;
                
                CFU_irrigation_plant_daily(i, j, day_idx) = ...
                    CFU_irrigation_plant_daily(i, j, day_idx) + current_cfu;
                
                % decay for next day
                if k < length(harvest_day_range)
                    log_reduction = daily_decay_rate * 1;
                    current_cfu = 10^(log10(current_cfu + 1e-10) - log_reduction);
                end
            end
        end
    end
    
    if mod(i, 50) == 0
        fprintf('  Daily irrigation tracking: Iteration %d/%d complete\n', i, iterations);
    end
end

% daily avg across plants
for i = 1:iterations
    for day = 1:365
        CFU_irrigation_daily(i, day) = mean(CFU_irrigation_plant_daily(i, :, day));
    end
end

fprintf('  Daily irrigation matrix created: [%d iterations × %d days]\n', iterations, 365);
fprintf('  Mean CFU across all days: %.2e\n', mean(CFU_irrigation_daily(:)));
fprintf('  Max daily CFU: %.2e (Day %d, Iter %d)\n', ...
        max(CFU_irrigation_daily(:)), ...
        find(CFU_irrigation_daily == max(CFU_irrigation_daily(:)), 1));

%% ========================================================================
%  SECTION 4.4: MONTHLY AGGREGATION - IRRIGATION
%% ========================================================================
fprintf('\nAggregating to monthly irrigation pathway data...\n');

CFU_irrigation_monthly_avg = zeros(iterations, 12);

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];

for i = 1:iterations
    for month = 1:12
        day_start = month_boundaries(month) + 1;
        day_end = month_boundaries(month + 1);
        
        CFU_irrigation_monthly_avg(i, month) = mean(CFU_irrigation_daily(i, day_start:day_end));
    end
end

fprintf('  Monthly irrigation matrix created: [%d iterations × 12 months]\n', iterations, 12);

months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
fprintf('\n  Monthly Mean CFU (averaged across iterations):\n');
fprintf('  %-6s  %12s\n', 'Month', 'Mean CFU');
fprintf('  %s\n', repmat('-', 1, 20));
for m = 1:12
    fprintf('  %-6s  %12.2e\n', months{m}, mean(CFU_irrigation_monthly_avg(:, m)));
end

fprintf('\n========== IRRIGATION DAILY/MONTHLY TRACKING COMPLETE ==========\n');



%% PATHWAY 2: SOIL -> ONION SURFACE (field curing)
fprintf('\nCalculating Pathway 2: Soil transfer during field curing...\n');

for i = 1:iterations
    last_irrig_day = har1(i) - irr_stop;
    
    % Racine prevalence sampling
    prev0 = random(makedist('Triangular', 'a', prev_min(3), ...
                            'b', (prev_min(3)+prev_min(1))/2, 'c', prev_min(1))) / 100;
    n_infected = round(prev0 * plantnum);
    infected_idx = randperm(plantnum, n_infected);
    
    for j = 1:plantnum
        cfu_from_soil = 0;
        
        % weekly transfer during curing
        for k = last_irrig_day:7:har1(i)
            day_idx = mod(k - 1, 365) + 1;
            
            if k < har1(i)
                month = get_month_index_jul_start(day_idx);
                if month > 12, month = 12; end
                
                transfer_coefficient = pert_min + (pert_max - pert_min) * random(beta_dist, 1);
                
                CFU_transfer = transfer_coefficient * CFU_soil(i, j, day_idx);
                cfu_from_soil = cfu_from_soil + CFU_transfer;
                
                cfu_from_soil = 10^(log10(cfu_from_soil + 1e-10) + monthly_decay(month));
            end
        end
        
        % Racine prevalence with linear decay
        if ismember(j, infected_idx)
            days_to_harvest = har1(i) - last_irrig_day;
            
            predicted_mpn = max(0, curing_intercept(i) + curing_slope(i) * days_to_harvest);
            
            cfu_from_soil = cfu_from_soil + 10^(predicted_mpn);
        end
        
        CFU_soil_pathway(i, j) = cfu_from_soil;
    end
    
    if mod(i, 50) == 0
        fprintf('  Pathway 2: Iteration %d/%d complete\n', i, iterations);
    end
end

%% ========================================================================
%  SECTION 4.5: DAILY SOIL PATHWAY TRACKING
%% ========================================================================

CFU_soil_pathway_daily_v2 = zeros(iterations, 365);
CFU_soil_pathway_plant_daily = zeros(iterations, plantnum, 365);

for i = 1:iterations
    last_irrig_day = har1(i) - irr_stop;
    
    prev0 = random(makedist('Triangular', 'a', prev_min(3), ...
                            'b', (prev_min(3)+prev_min(1))/2, 'c', prev_min(1))) / 100;
    n_infected = round(prev0 * plantnum);
    infected_idx = randperm(plantnum, n_infected);
    
    for j = 1:plantnum
        cumulative_cfu = 0;
        
        transfer_days = last_irrig_day:7:har1(i);
        
        for k_idx = 1:length(transfer_days)
            k = transfer_days(k_idx);
            
            if k >= har1(i)
                break;
            end
            
            day_idx = mod(k - 1, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            
            transfer_coefficient = pert_min + (pert_max - pert_min) * random(beta_dist, 1);
            CFU_transfer = transfer_coefficient * CFU_soil(i, j, day_idx);
            cumulative_cfu = cumulative_cfu + CFU_transfer;
            
            CFU_soil_pathway_plant_daily(i, j, day_idx) = ...
                CFU_soil_pathway_plant_daily(i, j, day_idx) + CFU_transfer;
            
            if k_idx < length(transfer_days)
                next_transfer = transfer_days(k_idx + 1);
                decay_end = min(next_transfer - 1, har1(i) - 1);
            else
                decay_end = har1(i) - 1;
            end
            
            current_day = k;
            current_cfu_from_this_transfer = CFU_transfer;
            
            while current_day < decay_end
                current_day = current_day + 1;
                day_idx_decay = mod(current_day - 1, 365) + 1;
                month_decay = get_month_index_jul_start(day_idx_decay);
                if month_decay > 12, month_decay = 12; end
                
                current_cfu_from_this_transfer = 10^(log10(current_cfu_from_this_transfer + 1e-10) + ...
                                                      monthly_decay(month_decay));
                
                CFU_soil_pathway_plant_daily(i, j, day_idx_decay) = ...
                    CFU_soil_pathway_plant_daily(i, j, day_idx_decay) + current_cfu_from_this_transfer;
            end
        end
        
        % Racine prevalence additioncurrent_day = k;
            current_cfu_from_this_transfer = CFU_transfer;
            
            while current_day < decay_end
                current_day = current_day + 1;
                day_idx_decay = mod(current_day - 1, 365) + 1;
                month_decay = get_month_index_jul_start(day_idx_decay);
                if month_decay > 12, month_decay = 12; end
                
                current_cfu_from_this_transfer = 10^(log10(current_cfu_from_this_transfer + 1e-10) + ...
                                                      monthly_decay(month_decay));
                
                CFU_soil_pathway_plant_daily(i, j, day_idx_decay) = ...
                    CFU_soil_pathway_plant_daily(i, j, day_idx_decay) + current_cfu_from_this_transfer;
            end
        end
        
        if ismember(j, infected_idx)
            days_to_harvest = har1(i) - last_irrig_day;
            
            predicted_mpn = max(0, curing_intercept(i) + curing_slope(i) * days_to_harvest);
            
            harv_day_idx = mod(har1(i) - 1, 365) + 1;
            CFU_soil_pathway_plant_daily(i, j, harv_day_idx) = ...
                CFU_soil_pathway_plant_daily(i, j, harv_day_idx) + 10^(predicted_mpn);
        end
    end
    
    if mod(i, 50) == 0
        fprintf('  Daily soil pathway tracking: Iteration %d/%d complete\n', i, iterations);
    end
end

for i = 1:iterations
    for day = 1:365
        CFU_soil_pathway_daily_v2(i, day) = mean(CFU_soil_pathway_plant_daily(i, :, day));
    end
end

fprintf('  Daily soil pathway matrix created: [%d iterations x %d days]\n', iterations, 365);
fprintf('  Mean CFU across all days: %.2e\n', mean(CFU_soil_pathway_daily_v2(:)));
fprintf('  Max daily CFU: %.2e\n', max(CFU_soil_pathway_daily_v2(:)));

%% ========================================================================
%  SECTION 4.6: MONTHLY AGGREGATION - SOIL PATHWAY
%% ========================================================================
fprintf('\nAggregating to monthly soil pathway data...\n');

CFU_soil_pathway_monthly_avg = zeros(iterations, 12);

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];

for i = 1:iterations
    for month = 1:12
        day_start = month_boundaries(month) + 1;
        day_end = month_boundaries(month + 1);
        
        CFU_soil_pathway_monthly_avg(i, month) = mean(CFU_soil_pathway_daily_v2(i, day_start:day_end));
    end
end

fprintf('  Monthly soil pathway matrix created: [%d iterations × 12 months]\n', iterations, 12);

months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
fprintf('\n  Monthly Mean CFU (averaged across iterations):\n');
fprintf('  %-6s  %12s\n', 'Month', 'Mean CFU');
fprintf('  %s\n', repmat('-', 1, 20));
for m = 1:12
    fprintf('  %-6s  %12.2e\n', months{m}, mean(CFU_soil_pathway_monthly_avg(:, m)));
end

fprintf('\n========== SOIL PATHWAY DAILY/MONTHLY TRACKING COMPLETE ==========\n');



%% ========================================================================
%  SECTION 4.8: VALIDATION CHECK
%% ========================================================================
% sanity check: pathway 2 final values vs daily tracking version
fprintf('\n========== VALIDATION CHECK ==========\n');
fprintf('Comparing final values with original CFU_soil_pathway:\n\n');

for i = 1:min(5, iterations)
    harv_day_idx = mod(har1(i) - 1, 365) + 1;
    
    original_mean = mean(CFU_soil_pathway(i, :));
    
    daily_sum = sum(CFU_soil_pathway_daily_v2(i, :));
    
    harvest_day_value = CFU_soil_pathway_daily_v2(i, harv_day_idx);
    
    fprintf('Iteration %d:\n', i);
    fprintf('  Original CFU_soil_pathway (mean): %.4e\n', original_mean);
    fprintf('  Harvest day value (daily): %.4e\n', harvest_day_value);
    fprintf('  Total daily sum: %.4e\n', daily_sum);Max_crop1
    fprintf('  Harvest day: %d\n\n', har1(i));
end

fprintf('Note: Daily tracking spreads contamination across the curing period,\n');
fprintf('while original CFU_soil_pathway shows the final accumulated value.\n');
fprintf('========================================\n');



%% ========================================================================
%  COMBINE PATHWAYS
%% ========================================================================
fprintf('\n--- Combining both pathways ---\n');

% using soil pathway as total for now
CFU_crop1 =  CFU_soil_pathway;

fprintf('\nCONTAMINATION SUMMARY:\n');
fprintf('  Pathway 1 (Irrigation Water):\n');
fprintf('    Mean CFU: %.2e\n', mean(CFU_onion_survival(:)));
fprintf('    Max CFU: %.2e\n', max(CFU_onion_survival(:)));
fprintf('    Non-zero samples: %d (%.1f%%)\n', ...
        sum(CFU_onion_survival(:) > 0), ...
        sum(CFU_onion_survival(:) > 0) / numel(CFU_onion_survival) * 100);

fprintf('\n  Pathway 2 (Soil Transfer):\n');
fprintf('    Mean CFU: %.2e\n', mean(CFU_soil_pathway(:)));
fprintf('    Max CFU: %.2e\n', max(CFU_soil_pathway(:)));
fprintf('    Non-zero samples: %d (%.1f%%)\n', ...
        sum(CFU_soil_pathway(:) > 0), ...
        sum(CFU_soil_pathway(:) > 0) / numel(CFU_soil_pathway) * 100);

fprintf('\n  Combined Total:\n');
fprintf('    Mean CFU: %.2e\n', mean(CFU_crop1(:)));
fprintf('    Median CFU: %.2e\n', median(CFU_crop1(:)));
fprintf('    Max CFU: %.2e\n', max(CFU_crop1(:)));
fprintf('    Std Dev: %.2e\n', std(CFU_crop1(:)));

CFU_combined_total = CFU_soil_pathway + CFU_onion_survival;
irrigation_contribution = mean(CFU_onion_survival(:)) / mean(CFU_combined_total(:)) * 100;
soil_contribution       = mean(CFU_soil_pathway(:))   / mean(CFU_combined_total(:)) * 100;


fprintf('\n  Pathway Contributions:\n');
fprintf('    Irrigation water: %.1f%% of total\n', irrigation_contribution);
fprintf('    Soil transfer: %.1f%% of total\n', soil_contribution);


%% ========================================================================
%  SECTION 5: ORGANIZE BY HARVEST MONTH
%% ========================================================================
fprintf('\nOrganizing outputs by harvest month...\n');

CFU_crop1_monthly = cell(12, 1);
CFU_irrigation_monthly = cell(12, 1);
CFU_soil_monthly = cell(12, 1);

for m = 1:12
    CFU_crop1_monthly{m} = [];
    CFU_irrigation_monthly{m} = [];
    CFU_soil_monthly{m} = [];
end

for i = 1:iterations
    month1 = ceil(har1(i) / 30.5);
    if month1 > 12, month1 = 12; end
    
    CFU_crop1_monthly{month1} = [CFU_crop1_monthly{month1}; CFU_crop1(i, :)];
    CFU_irrigation_monthly{month1} = [CFU_irrigation_monthly{month1}; CFU_onion_survival(i, :)];
    CFU_soil_monthly{month1} = [CFU_soil_monthly{month1}; CFU_soil_pathway(i, :)];
end

months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

 = zeros(12, 1);
Mean_crop1 = zeros(12, 1);
Prevalence_crop1 = zeros(12, 1);
Mean_irrigation = zeros(12, 1);
Mean_soil = zeros(12, 1);
LOD = 10;  % detection limit (onion-surface CFU/plant)

for m = 1:12
    if ~isempty(CFU_crop1_monthly{m})
        Max_crop1(m) = max(CFU_crop1_monthly{m}(:));
        Mean_crop1(m) = mean(CFU_crop1_monthly{m}(:));
        Prevalence_crop1(m) = sum(CFU_crop1_monthly{m}(:) >= LOD) / numel(CFU_crop1_monthly{m}) * 100;
        Mean_irrigation(m) = mean(CFU_irrigation_monthly{m}(:));
        Mean_soil(m) = mean(CFU_soil_monthly{m}(:));
    end
end

fprintf('Output organization complete!\n');

%% ========================================================================
%  SECTION 6: RESULTS SUMMARY
%% ========================================================================
fprintf('\n========== RESULTS SUMMARY ==========\n');

fprintf('\nOVERALL CONTAMINATION (CROP 1):\n');
fprintf('  Mean CFU: %.2e\n', mean(CFU_crop1(:)));
fprintf('  Median CFU: %.2e\n', median(CFU_crop1(:)));
fprintf('  Max CFU: %.2e\n', max(CFU_crop1(:)));
fprintf('  Std Dev: %.2e\n', std(CFU_crop1(:)));
fprintf('  Overall Prevalence (>%d CFU): %.2f%%\n', LOD, ...
        sum(CFU_crop1(:) >= LOD) / numel(CFU_crop1) * 100);

fprintf('\nPATHWAY CONTRIBUTIONS:\n');
fprintf('  Irrigation water pathway:\n');
fprintf('    Mean: %.2e CFU (%.1f%% of total)\n', ...
        mean(CFU_onion_survival(:)), ...
        mean(CFU_onion_survival(:)) / mean(CFU_crop1(:)) * 100);

fprintf('  Soil transfer pathway:\n');
fprintf('    Mean: %.2e CFU (%.1f%% of total)\n', ...
        mean(CFU_soil_pathway(:)), ...
        mean(CFU_soil_pathway(:)) / mean(CFU_crop1(:)) * 100);

fprintf('\nDECAY MODEL SUMMARY:\n');
fprintf('  Irrigation pathway: Linear (k=%.4f/day, survival=%.4f/day)\n', ...
        daily_decay_rate, survival_multiplier);

fprintf('\nMONTHLY BREAKDOWN:\n');
fprintf('%-6s  %12s  %12s  %12s  %12s  %10s\n', ...
        'Month', 'Mean Total', 'Mean Irrig', 'Mean Soil', 'Max CFU', 'Prev %');
fprintf('%s\n', repmat('-', 1, 80));

for m = 1:12
    if Mean_crop1(m) > 0
        fprintf('%-6s  %12.2e  %12.2e  %12.2e  %12.2e  %10.2f\n', ...
                months{m}, Mean_crop1(m), Mean_irrigation(m), Mean_soil(m), ...
                Max_crop1(m), Prevalence_crop1(m));
    end
end
fprintf('\nDAILY SOIL CFU TRACKING:\n');
fprintf('  Mean daily CFU: %.2e\n', mean(CFU_daily(:)));
[~, peak_day] = max(mean(CFU_daily, 1));
fprintf('  Peak contamination: Day %d\n', peak_day);

fprintf('\n========== SIMULATION COMPLETE ==========\n');
%% ========================================================================
%  SECTION 7: VISUALIZATION
%% ========================================================================
fprintf('\nGenerating visualizations (log scale)...\n');

%% Figure 1: pathway distributions
figure(1); clf;

subplot(1,3,1);
data1 = CFU_onion_survival(CFU_onion_survival > 0);
if ~isempty(data1)
    histogram(log10(data1), 30, 'FaceColor', 'b', 'EdgeColor', 'w');
end
xlabel('log_{10}(CFU)');
ylabel('Frequency');
title('Irrigation Water Pathway');
grid on;

subplot(1,3,2);
data2 = CFU_soil_pathway(CFU_soil_pathway > 0);
if ~isempty(data2)
    histogram(log10(data2), 30, 'FaceColor', 'r', 'EdgeColor', 'w');
end
xlabel('log_{10}(CFU)');
ylabel('Frequency');
title('Soil Transfer Pathway');
grid on;

subplot(1,3,3);
data3 = CFU_crop1(CFU_crop1 > 0);
if ~isempty(data3)
    histogram(log10(data3), 30, 'FaceColor', 'g', 'EdgeColor', 'w');
end
xlabel('log_{10}(CFU)');
ylabel('Frequency');
title('Combined Total');
grid on;

sgtitle('Contamination Distribution (Log Scale)');

%% Figure 2: monthly prevalence
figure(2); clf;
bar(Prevalence_crop1);
set(gca, 'XTickLabel', months);
xlabel('Harvest Month');
ylabel('Prevalence (%)');
title('Prevalence of Contaminated Onions by Month');
grid on;
set(gca, 'YScale', 'log');
ylim([0.1 100]);

%% Figure 3: pathway contribution by month
figure(3); clf;
bar([Mean_irrigation', Mean_soil'], 'stacked');
set(gca, 'XTickLabel', months);
xlabel('Harvest Month');
ylabel('Mean log CFU per subplot');
legend('Irrigation Water', 'Soil Transfer');
title('Contamination Pathway Contributions by Month');
grid on;
set(gca, 'YScale', 'log');
ylim([1e-5 1e5]);

%% Figure 4: daily soil CFU trend
figure(4); clf;
semilogy(1:365, mean(CFU_daily, 1), 'b-', 'LineWidth', 2);
xlabel('Day of Year'); 
ylabel('Mean log CFU per subplot');
title('Daily Soil CFU Trends (Log Scale)');
grid on;
ylim([1 1e10]);

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

fprintf('Visualizations complete!\n');

%% Figure 5: irrigation pathway time-series
fprintf('\nGenerating irrigation pathway time-series visualization...\n');

figure(5); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

subplot(2,1,1);
daily_mean = mean(CFU_irrigation_daily, 1);
daily_std = std(CFU_irrigation_daily, 0, 1);

semilogy(1:365, max(daily_mean, 1e-10), 'b-', 'LineWidth', 2);
hold on;

upper = max(daily_mean + daily_std, 1e-10);
lower = max(daily_mean - daily_std, 1e-10);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot ', 'FontSize', 11);
title('CFU Onion Survival (Secondary output)', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
xlim([1 365]);
ylim([1e-5 1e5]);

xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

subplot(2,1,2);
monthly_mean = mean(CFU_irrigation_monthly_avg, 1);
bar(monthly_mean);
set(gca, 'XTickLabel', months);
xlabel('Month', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('Monthly Average Irrigation Pathway Contamination', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
set(gca, 'YScale', 'log');
ylim([1e-5 1e5]);

fprintf('Irrigation pathway visualization complete!\n');

%% Figure 6: pathway comparison
figure(6); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

daily_irrig = mean(CFU_irrigation_daily, 1);
daily_soil = mean(CFU_soil_pathway_daily_v2, 1);

subplot(3,1,1);
semilogy(1:365, max(daily_irrig, 1e-10), 'b-', 'LineWidth', 2, 'DisplayName', 'Irrigation');
hold on;
semilogy(1:365, max(daily_soil, 1e-10), 'r-', 'LineWidth', 2, 'DisplayName', 'Transferred soil contam. to onion surface');

xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('Daily Pathway Comparison (Averaged Across Iterations)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best');
grid on;
xlim([1 365]);

xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

subplot(3,1,2);
monthly_irrig = mean(CFU_irrigation_monthly_avg, 1);
monthly_soil = mean(CFU_soil_pathway_monthly_avg, 1);

bar([monthly_irrig; monthly_soil]');
set(gca, 'XTickLabel', months);
xlabel('Month', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('Monthly Pathway Comparison', 'FontSize', 12, 'FontWeight', 'bold');
legend('Irrigation', 'Soil Transfer', 'Location', 'best');
grid on;
set(gca, 'YScale', 'log');
ylim([1e-5 1e5]);

subplot(3,1,3);
cumulative_irrig = cumsum(daily_irrig);
cumulative_soil = cumsum(daily_soil);

semilogy(1:365, max(cumulative_irrig, 1e-10), 'b-', 'LineWidth', 2, 'DisplayName', 'Irrigation');
hold on;
semilogy(1:365, max(cumulative_soil, 1e-10), 'r-', 'LineWidth', 2, 'DisplayName', 'Soil Transfer');

xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot ', 'FontSize', 11);
title('Cumulative Contamination Over Time', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best');
grid on;
xlim([1 365]);

xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

fprintf('Pathway comparison visualization complete!\n');


%% Figure 7: soil pathway detail
figure(7); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

daily_mean_soil = mean(CFU_soil_pathway_daily_v2, 1);
daily_std_soil = std(CFU_soil_pathway_daily_v2, 0, 1);

subplot(2,1,1);
semilogy(1:365, max(daily_mean_soil, 1e-10), 'r-', 'LineWidth', 2);
hold on;

upper = max(daily_mean_soil + daily_std_soil, 1e-10);
lower = max(daily_mean_soil - daily_std_soil, 1e-10);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('CFU Crop(14 days before harvesting)', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
xlim([1 365]);
ylim([1e-5 1e5]);

xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

subplot(2,1,2);
monthly_mean_soil = mean(CFU_soil_pathway_monthly_avg, 1);
bar(monthly_mean_soil);
set(gca, 'XTickLabel', months);
xlabel('Month', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('Monthly Average Soil Pathway Contamination', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
set(gca, 'YScale', 'log');
ylim([1e-5 1e5]);

fprintf('Soil pathway visualization complete!\n');



%% Figure 8: combined 3-panel overview
figure(8); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

daily_irrigation_mean = mean(CFU_irrigation_daily, 1);
daily_irrigation_std = std(CFU_irrigation_daily, 0, 1);
daily_soil_pathway_mean = mean(CFU_soil_pathway_daily_v2, 1);
daily_soil_pathway_std = std(CFU_soil_pathway_daily_v2, 0, 1);
daily_cfu_mean = mean(CFU_daily, 1);
daily_cfu_std = std(CFU_daily, 0, 1);

subplot(3, 1, 1);
semilogy(1:365, max(daily_cfu_mean, 1e-10), 'g-', 'LineWidth', 2);
hold on;
upper = max(daily_cfu_mean + daily_cfu_std, 1e-10);
lower = max(daily_cfu_mean - daily_cfu_std, 1e-6);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('CFU Soil (WILDLIFE + IRRIGATION CONT.)', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([1 365]); ylim([1e-6 1e5]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(3, 1, 2);
semilogy(1:365, max(daily_irrigation_mean, 1e-10), 'b-', 'LineWidth', 2);
hold on;
upper = max(daily_irrigation_mean + daily_irrigation_std, 1e-6);
lower = max(daily_irrigation_mean - daily_irrigation_std, 1e-6);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('CFU onion survival (Secondary output)', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([1 365]); ylim([1e-5 1e5]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(3, 1, 3);
semilogy(1:365, max(daily_soil_pathway_mean, 1e-10), 'r-', 'LineWidth', 2);
hold on;
upper = max(daily_soil_pathway_mean + daily_soil_pathway_std, 1e-10);
lower = max(daily_soil_pathway_mean - daily_soil_pathway_std, 1e-10);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean log CFU per subplot', 'FontSize', 11);
title('CFU crop1 (14 days before harvesting)', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([1 365]); ylim([1e-5 1e5]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

sgtitle('Comprehensive Daily Contamination Pathways Analysis (Log Scale)', ...
        'FontSize', 14, 'FontWeight', 'bold');

fprintf('Combined visualization complete!\n');
%% ========================================================================
%  SECTION 8: MONTHLY PERCENTILE STATISTICS
%% ========================================================================
% percentiles per iteration for each month from the daily tracking matrices
fprintf('\n========== MONTHLY PERCENTILE STATISTICS ==========\n');

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

% --- CFU_daily (soil) ---
fprintf('\nProcessing CFU_daily (Soil)...\n');
CFU_daily_monthly_min = zeros(iterations,12); CFU_daily_monthly_p05 = zeros(iterations,12);
CFU_daily_monthly_p25 = zeros(iterations,12); CFU_daily_monthly_p50 = zeros(iterations,12);
CFU_daily_monthly_p75 = zeros(iterations,12); CFU_daily_monthly_p95 = zeros(iterations,12);
CFU_daily_monthly_max = zeros(iterations,12);

for i = 1:iterations
    for m = 1:12
        ds = month_boundaries(m)+1; de = month_boundaries(m+1);
        data = CFU_daily(i, ds:de);
        CFU_daily_monthly_min(i,m) = min(data);
        CFU_daily_monthly_p05(i,m) = prctile(data, 5);
        CFU_daily_monthly_p25(i,m) = prctile(data, 25);
        CFU_daily_monthly_p50(i,m) = prctile(data, 50);
        CFU_daily_monthly_p75(i,m) = prctile(data, 75);
        CFU_daily_monthly_p95(i,m) = prctile(data, 95);
        CFU_daily_monthly_max(i,m) = max(data);
    end
end
fprintf('  CFU_daily percentile matrices: [%d x 12]\n', iterations);

% --- CFU_irrigation_daily ---
fprintf('Processing CFU_irrigation_daily...\n');
CFU_irrig_monthly_min = zeros(iterations,12); CFU_irrig_monthly_p05 = zeros(iterations,12);
CFU_irrig_monthly_p25 = zeros(iterations,12); CFU_irrig_monthly_p50 = zeros(iterations,12);
CFU_irrig_monthly_p75 = zeros(iterations,12); CFU_irrig_monthly_p95 = zeros(iterations,12);
CFU_irrig_monthly_max = zeros(iterations,12);

for i = 1:iterations
    for m = 1:12
        ds = month_boundaries(m)+1; de = month_boundaries(m+1);
        data = CFU_irrigation_daily(i, ds:de);
        CFU_irrig_monthly_min(i,m) = min(data);
        CFU_irrig_monthly_p05(i,m) = prctile(data, 5);
        CFU_irrig_monthly_p25(i,m) = prctile(data, 25);
        CFU_irrig_monthly_p50(i,m) = prctile(data, 50);
        CFU_irrig_monthly_p75(i,m) = prctile(data, 75);
        CFU_irrig_monthly_p95(i,m) = prctile(data, 95);
        CFU_irrig_monthly_max(i,m) = max(data);
    end
end
fprintf('  CFU_irrigation_daily percentile matrices: [%d x 12]\n', iterations);

% --- CFU_soil_pathway_daily_v2 ---
fprintf('Processing CFU_soil_pathway_daily_v2...\n');
CFU_soilpath_monthly_min = zeros(iterations,12); CFU_soilpath_monthly_p05 = zeros(iterations,12);
CFU_soilpath_monthly_p25 = zeros(iterations,12); CFU_soilpath_monthly_p50 = zeros(iterations,12);
CFU_soilpath_monthly_p75 = zeros(iterations,12); CFU_soilpath_monthly_p95 = zeros(iterations,12);
CFU_soilpath_monthly_max = zeros(iterations,12);

for i = 1:iterations
    for m = 1:12
        ds = month_boundaries(m)+1; de = month_boundaries(m+1);
        data = CFU_soil_pathway_daily_v2(i, ds:de);
        CFU_soilpath_monthly_min(i,m) = min(data);
        CFU_soilpath_monthly_p05(i,m) = prctile(data, 5);
        CFU_soilpath_monthly_p25(i,m) = prctile(data, 25);
        CFU_soilpath_monthly_p50(i,m) = prctile(data, 50);
        CFU_soilpath_monthly_p75(i,m) = prctile(data, 75);
        CFU_soilpath_monthly_p95(i,m) = prctile(data, 95);
        CFU_soilpath_monthly_max(i,m) = max(data);
    end
end
fprintf('  CFU_soil_pathway_daily_v2 percentile matrices: [%d x 12]\n', iterations);

% summary tables
fprintf('\n========== SUMMARY: Mean of Monthly Percentiles ==========\n');
stat_names = {'Min', 'P5', 'P25', 'P50', 'P75', 'P95', 'Max'};

fprintf('\n--- CFU_daily (Soil CFU) ---\n');
fprintf('%-6s  %12s  %12s  %12s  %12s  %12s  %12s  %12s\n', 'Month', stat_names{:});
fprintf('%s\n', repmat('-', 1, 96));
for m = 1:12
    fprintf('%-6s  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e\n', months{m}, ...
        mean(CFU_daily_monthly_min(:,m)), mean(CFU_daily_monthly_p05(:,m)), ...
        mean(CFU_daily_monthly_p25(:,m)), mean(CFU_daily_monthly_p50(:,m)), ...
        mean(CFU_daily_monthly_p75(:,m)), mean(CFU_daily_monthly_p95(:,m)), ...
        mean(CFU_daily_monthly_max(:,m)));
end

fprintf('\n--- CFU_irrigation_daily (Irrigation Pathway) ---\n');
fprintf('%-6s  %12s  %12s  %12s  %12s  %12s  %12s  %12s\n', 'Month', stat_names{:});
fprintf('%s\n', repmat('-', 1, 96));
for m = 1:12
    fprintf('%-6s  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e\n', months{m}, ...
        mean(CFU_irrig_monthly_min(:,m)), mean(CFU_irrig_monthly_p05(:,m)), ...
        mean(CFU_irrig_monthly_p25(:,m)), mean(CFU_irrig_monthly_p50(:,m)), ...
        mean(CFU_irrig_monthly_p75(:,m)), mean(CFU_irrig_monthly_p95(:,m)), ...
        mean(CFU_irrig_monthly_max(:,m)));
end

fprintf('\n--- CFU_soil_pathway_daily_v2 (Soil Transfer Pathway) ---\n');
fprintf('%-6s  %12s  %12s  %12s  %12s  %12s  %12s  %12s\n', 'Month', stat_names{:});
fprintf('%s\n', repmat('-', 1, 96));
for m = 1:12
    fprintf('%-6s  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e  %12.2e\n', months{m}, ...
        mean(CFU_soilpath_monthly_min(:,m)), mean(CFU_soilpath_monthly_p05(:,m)), ...
        mean(CFU_soilpath_monthly_p25(:,m)), mean(CFU_soilpath_monthly_p50(:,m)), ...
        mean(CFU_soilpath_monthly_p75(:,m)), mean(CFU_soilpath_monthly_p95(:,m)), ...
        mean(CFU_soilpath_monthly_max(:,m)));
end

fprintf('\n========== MONTHLY PERCENTILE STATISTICS COMPLETE ==========\n');
%% ========================================================================
%  SECTION 8.5: DAILY PERCENTILE LINE GRAPHS
%% ========================================================================
% percentiles across iterations for each day (365 days)
% gives distribution of the predicted mean soil CFU
fprintf('\n========== DAILY PERCENTILE LINE GRAPHS ==========\n');
fprintf('Computing percentiles across %d iterations for each day...\n', iterations);

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
days = 1:365;

% soil percentiles [7 x 365]: min, p5, p25, p50, p75, p95, max
soil_pct = zeros(7, 365);
for d = 1:365
    vals = CFU_daily(:, d);
    soil_pct(1,d) = min(vals);
    soil_pct(2,d) = prctile(vals, 5);
    soil_pct(3,d) = prctile(vals, 25);
    soil_pct(4,d) = prctile(vals, 50);
    soil_pct(5,d) = prctile(vals, 75);
    soil_pct(6,d) = prctile(vals, 95);
    soil_pct(7,d) = max(vals);
end

% irrigation percentiles
irrig_pct = zeros(7, 365);
for d = 1:365
    vals = CFU_irrigation_daily(:, d);
    irrig_pct(1,d) = min(vals);
    irrig_pct(2,d) = prctile(vals, 5);
    irrig_pct(3,d) = prctile(vals, 25);
    irrig_pct(4,d) = prctile(vals, 50);
    irrig_pct(5,d) = prctile(vals, 75);
    irrig_pct(6,d) = prctile(vals, 95);
    irrig_pct(7,d) = max(vals);
end

% soil transfer pathway percentiles
soilpath_pct = zeros(7, 365);
for d = 1:365
    vals = CFU_soil_pathway_daily_v2(:, d);
    soilpath_pct(1,d) = min(vals);
    soilpath_pct(2,d) = prctile(vals, 5);
    soilpath_pct(3,d) = prctile(vals, 25);
    soilpath_pct(4,d) = prctile(vals, 50);
    soilpath_pct(5,d) = prctile(vals, 75);
    soilpath_pct(6,d) = prctile(vals, 95);
    soilpath_pct(7,d) = max(vals);
end

fprintf('  Percentile computation complete.\n');

% data range check
fprintf('\n  --- Data Range Check ---\n');
fprintf('  CFU_daily:              min=%.2e, max=%.2e\n', min(CFU_daily(:)), max(CFU_daily(:)));
fprintf('  CFU_irrigation_daily:   min=%.2e, max=%.2e\n', min(CFU_irrigation_daily(:)), max(CFU_irrigation_daily(:)));
fprintf('  CFU_soil_pathway_daily: min=%.2e, max=%.2e\n', min(CFU_soil_pathway_daily_v2(:)), max(CFU_soil_pathway_daily_v2(:)));

% plot styling
pct_labels = {'Min', '5th Percentile', '25th Percentile', ...
              '50th Percentile (Median)', '75th Percentile', ...
              '95th Percentile', 'Max'};

pct_colors = [0.6 0.6 0.6;   ...
              0.0 0.6 0.9;   ...
              0.0 0.3 0.7;   ...
              0.9 0.0 0.0;   ...
              1.0 0.5 0.0;   ...
              0.6 0.0 0.6;   ...
              0.2 0.2 0.2];

pct_styles = {':', '--', '-.', '-', '-.', '--', ':'};
pct_widths = [1.0, 1.2, 1.5, 2.5, 1.5, 1.2, 1.0];

% Figure 9: soil CFU daily percentiles
figure(9); clf;

for p = 1:7
    plot(days, log10(soil_pct(p,:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), ...
        'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end

fill([days, fliplr(days)], ...
     [log10(soil_pct(5,:)+1), fliplr(log10(soil_pct(3,:)+1))], ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([days, fliplr(days)], ...
     [log10(soil_pct(6,:)+1), fliplr(log10(soil_pct(2,:)+1))], ...
     [0.5 0.2 0.7], 'FaceAlpha', 0.06, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;

xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Daily Predicted E. coli in Soil per Subplot - Baseline', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1)
    xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
end
fprintf('  Figure 9 created: Soil CFU daily percentiles\n');

% Figure 10: irrigation pathway percentiles
figure(10); clf;

for p = 1:7
    plot(days, log10(irrig_pct(p,:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), ...
        'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end

fill([days, fliplr(days)], ...
     [log10(irrig_pct(5,:)+1), fliplr(log10(irrig_pct(3,:)+1))], ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([days, fliplr(days)], ...
     [log10(irrig_pct(6,:)+1), fliplr(log10(irrig_pct(2,:)+1))], ...
     [0.5 0.2 0.7], 'FaceAlpha', 0.06, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;

xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Daily Predicted E. coli - Irrigation Pathway per Subplot', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1)
    xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
end
fprintf('  Figure 10 created: Irrigation pathway daily percentiles\n');

% Figure 11: soil transfer pathway percentiles
figure(11); clf;

for p = 1:7
    plot(days, log10(soilpath_pct(p,:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), ...
        'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end

fill([days, fliplr(days)], ...
     [log10(soilpath_pct(5,:)+1), fliplr(log10(soilpath_pct(3,:)+1))], ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([days, fliplr(days)], ...
     [log10(soilpath_pct(6,:)+1), fliplr(log10(soilpath_pct(2,:)+1))], ...
     [0.5 0.2 0.7], 'FaceAlpha', 0.06, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;

xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Daily Predicted E. coli - Soil Transfer Pathway per Subplot', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1)
    xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
end
fprintf('  Figure 11 created: Soil transfer pathway daily percentiles\n');

fprintf('\n  With iterations=%d, Min and Max may overlap with percentile lines.\n', iterations);
fprintf('  Use iterations >= 100 for distinct percentile bands.\n');
fprintf('\n========== DAILY PERCENTILE LINE GRAPHS COMPLETE ==========\n');

%% ========================================================================
%  SECTION 9: PLANTS EXCEEDING THRESHOLDS BY MONTH
%% ========================================================================
% count how many plants have CFU_crop1 above 1, 5, 10, 20 for each harvest month
fprintf('\n========== PLANTS EXCEEDING E. COLI THRESHOLDS ==========\n');

%thresholds = [10, 20, 50, 100];
thresholds = [1, 5, 10, 20];
n_thresh = length(thresholds);
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
month_boundaries_days = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];

% figure out which month each iteration harvests in
harvest_month = zeros(iterations, 1);
for i = 1:iterations
    har_day = mod(har1(i) - 1, 365) + 1;
    harvest_month(i) = find(har_day <= month_boundaries_days(2:end), 1, 'first');
    if isempty(harvest_month(i))
        harvest_month(i) = 12;
    end
end

fprintf('  Harvest month distribution:\n');
for m = 1:12
    n_in_month = sum(harvest_month == m);
    if n_in_month > 0
        fprintf('    %s: %d iterations\n', months{m}, n_in_month);
    end
end

% count plants above each threshold
plants_above = zeros(iterations, n_thresh);

for i = 1:iterations
    for t = 1:n_thresh
        plants_above(i, t) = sum(CFU_crop1(i, :) > thresholds(t));
    end
end

fprintf('\n  Overall plant counts exceeding thresholds (across all iterations):\n');
for t = 1:n_thresh
    fprintf('    > %d CFU: Mean = %.1f plants, Max = %d plants\n', ...
        thresholds(t), mean(plants_above(:,t)), max(plants_above(:,t)));
end

% group by harvest month
monthly_plant_counts = cell(12, n_thresh);
monthly_stats = struct();

for m = 1:12
    idx = find(harvest_month == m);
    for t = 1:n_thresh
        if ~isempty(idx)
            monthly_plant_counts{m, t} = plants_above(idx, t);
        else
            monthly_plant_counts{m, t} = [];
        end
    end
end

fprintf('\n========== DETAILED MONTHLY RESULTS ==========\n');

for t = 1:n_thresh
    fprintf('\n--- Threshold: > %d CFU ---\n', thresholds(t));
    fprintf('%-6s  %8s  %10s  %10s  %10s  %10s  %10s  %10s  %10s\n', ...
        'Month', 'N_Iter', 'Mean', 'Std', 'Min', 'P25', 'Median', 'P75', 'Max');
    fprintf('%s\n', repmat('-', 1, 92));
    for m = 1:12
        data = monthly_plant_counts{m, t};
        if ~isempty(data)
            fprintf('%-6s  %8d  %10.1f  %10.1f  %10d  %10.1f  %10.1f  %10.1f  %10d\n', ...
                months{m}, length(data), mean(data), std(data), ...
                min(data), prctile(data,25), median(data), prctile(data,75), max(data));
        end
    end
end

fprintf('\n========== AS PERCENTAGE OF TOTAL PLANTS (%d) ==========\n', plantnum);

for t = 1:n_thresh
    fprintf('\n--- Threshold: > %d CFU ---\n', thresholds(t));
    fprintf('%-6s  %8s  %12s  %12s  %12s  %12s\n', ...
        'Month', 'N_Iter', 'Mean %%', 'Std %%', 'Min %%', 'Max %%');
    fprintf('%s\n', repmat('-', 1, 65));
    for m = 1:12
        data = monthly_plant_counts{m, t};
        if ~isempty(data)
            pct_data = data / plantnum * 100;
            fprintf('%-6s  %8d  %12.4f  %12.4f  %12.4f  %12.4f\n', ...
                months{m}, length(data), mean(pct_data), std(pct_data), ...
                min(pct_data), max(pct_data));
        end
    end
end

% Figure 12: bar chart
% Figure 12: bar chart - Mean + Percentage subplots


figure(12); clf;

bar_data = zeros(12, n_thresh);
for m = 1:12
    for t = 1:n_thresh
        data = monthly_plant_counts{m, t};
        if ~isempty(data)
            bar_data(m, t) = mean(data);
        end
    end
end

active_months = any(bar_data > 0, 2);
if any(active_months)

    % --- subplot 1: original unchanged ---
    subplot(2, 1, 1);
    b = bar(bar_data(active_months, :));
    set(gca, 'XTickLabel', months(active_months));
    xlabel('Harvest Month', 'FontSize', 12);
    ylabel('Mean Number of Plants Exceeding Threshold', 'FontSize', 12);
    title('Mean Plants Exceeding E. coli Thresholds by Harvest Month', ...
          'FontSize', 13, 'FontWeight', 'bold');
    legend_labels = cell(n_thresh, 1);
    for t = 1:n_thresh
        legend_labels{t} = sprintf('> %d CFU', thresholds(t));
    end
    legend(legend_labels(1:length(b)), 'Location', 'best', 'FontSize', 10);
    grid on;
    for t = 1:length(b)
        xtips = b(t).XEndPoints;
        ytips = b(t).YEndPoints;
        labels = arrayfun(@(x) sprintf('%.0f', x), ytips, 'UniformOutput', false);
        text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
    end

    % --- subplot 2: new percentage panel ---
    subplot(2, 1, 2);
    pct_bar_data = bar_data / plantnum * 100;
    b2 = bar(pct_bar_data(active_months, :));
    set(gca, 'XTickLabel', months(active_months));
    xlabel('Harvest Month', 'FontSize', 12);
    ylabel(sprintf('%% of Total Plants (%d)', plantnum), 'FontSize', 12);
    title('Percentage of Plants Exceeding E. coli Thresholds by Harvest Month', ...
          'FontSize', 13, 'FontWeight', 'bold');
    legend_labels2 = cell(n_thresh, 1);
    for t = 1:n_thresh
        legend_labels2{t} = sprintf('> %d CFU', thresholds(t));
    end
    legend(legend_labels2(1:length(b2)), 'Location', 'best', 'FontSize', 10);
    grid on;
    for t = 1:length(b2)
        xtips = b2(t).XEndPoints;
        ytips = b2(t).YEndPoints;
        labels = arrayfun(@(x) sprintf('%.3f%%', x), ytips, 'UniformOutput', false);
        text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
    end

end

sgtitle('E. coli Threshold Analysis by Harvest Month', ...
        'FontSize', 14, 'FontWeight', 'bold');
fprintf('\n  Figure 12 created: Bar chart of plants exceeding thresholds\n');

% figure(12); clf;
% 
% bar_data = zeros(12, n_thresh);
% for m = 1:12
%     for t = 1:n_thresh
%         data = monthly_plant_counts{m, t};
%         if ~isempty(data)
%             bar_data(m, t) = mean(data);
%         end
%     end
% end
% 
% active_months = any(bar_data > 0, 2);
% if any(active_months)
%     b = bar(bar_data(active_months, :));
%     set(gca, 'XTickLabel', months(active_months));
%     xlabel('Harvest Month', 'FontSize', 12);
%     ylabel('Mean Number of Plants Exceeding Threshold', 'FontSize', 12);
%     title('Mean Plants Exceeding E. coli Thresholds by Harvest Month', ...
%           'FontSize', 13, 'FontWeight', 'bold');
%     legend_labels = cell(n_thresh, 1);
%     for t = 1:n_thresh
%         legend_labels{t} = sprintf('> %d CFU', thresholds(t));
%     end
%     legend(legend_labels(1:length(b)), 'Location', 'best', 'FontSize', 10);
%     grid on;
%     for t = 1:length(b)
%         xtips = b(t).XEndPoints;
%         ytips = b(t).YEndPoints;
%         labels = arrayfun(@(x) sprintf('%.0f', x), ytips, 'UniformOutput', false);
%         text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
%             'VerticalAlignment', 'bottom', 'FontSize', 8);
%     end
% end
% fprintf('\n  Figure 12 created: Bar chart of plants exceeding thresholds\n');



% Figure 13: percentage bar chart
figure(13); clf;

pct_bar_data = bar_data / plantnum * 100;

if any(active_months)
    b2 = bar(pct_bar_data(active_months, :));
    set(gca, 'XTickLabel', months(active_months));
    xlabel('Harvest Month', 'FontSize', 12);
    ylabel('Mean %% of Plants Exceeding Threshold', 'FontSize', 12);
    title('Percentage of Plants Exceeding E. coli Thresholds by Harvest Month', ...
          'FontSize', 13, 'FontWeight', 'bold');
    legend_labels2 = cell(n_thresh, 1);
    for t = 1:n_thresh
        legend_labels2{t} = sprintf('> %d CFU', thresholds(t));
    end
    legend(legend_labels2(1:length(b2)), 'Location', 'best', 'FontSize', 10);
    grid on;
    for t = 1:length(b2)
        xtips = b2(t).XEndPoints;
        ytips = b2(t).YEndPoints;
        labels = arrayfun(@(x) sprintf('%.2f%%', x), ytips, 'UniformOutput', false);
        text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
    end
end
fprintf('  Figure 13 created: Percentage bar chart\n');

% Figure 14: box plots
figure(14); clf;

for t = 1:n_thresh
    subplot(2, 2, t);
    
    box_data = [];
    box_groups = [];
    box_labels = {};
    label_idx = 0;
    
    for m = 1:12
        data = monthly_plant_counts{m, t};
        if ~isempty(data) && any(data > 0)
            label_idx = label_idx + 1;
            box_data = [box_data; data(:)];
            box_groups = [box_groups; repmat(label_idx, length(data), 1)];
            box_labels{label_idx} = months{m};
        end
    end
    
    if ~isempty(box_data)
        boxplot(box_data, box_groups, 'Labels', box_labels);
        ylabel('Number of Plants', 'FontSize', 10);
    else
        text(0.5, 0.5, 'No data above threshold', ...
             'Units', 'normalized', 'HorizontalAlignment', 'center');
    end
    title(sprintf('> %d CFU', thresholds(t)), 'FontSize', 11, 'FontWeight', 'bold');
    grid on;
end
sgtitle('Distribution of Plant Counts Exceeding Thresholds by Month', ...
        'FontSize', 13, 'FontWeight', 'bold');
fprintf('  Figure 14 created: Box plots\n');

fprintf('\n========== THRESHOLD ANALYSIS COMPLETE ==========\n');
%% ========================================================================
%  SECTION 10: CURING PERIOD (LAST 28 DAYS)
%% ========================================================================
% pull out last 28 days before harvest, align across iterations
fprintf('\n========== CURING PERIOD VISUALIZATION (28 DAYS) ==========\n');

curing_days = 28;

% d=1 is 27 days before harvest, d=28 is harvest day
curing_soil     = zeros(iterations, curing_days);
curing_irrig    = zeros(iterations, curing_days);
curing_soilpath = zeros(iterations, curing_days);

for i = 1:iterations
    for d = 1:curing_days
        actual_day = har1(i) - (curing_days - d);
        day_idx = mod(actual_day - 1, 365) + 1;
        
        curing_soil(i, d)     = CFU_daily(i, day_idx);
        curing_irrig(i, d)    = CFU_irrigation_daily(i, day_idx);
        curing_soilpath(i, d) = CFU_soil_pathway_daily_v2(i, day_idx);
    end
end

fprintf('  Extracted 28-day curing window for %d iterations.\n', iterations);
fprintf('  Harvest days range: %d to %d\n', min(har1), max(har1));

% percentiles across iterations for each curing day
cure_soil_pct     = zeros(7, curing_days);
cure_irrig_pct    = zeros(7, curing_days);
cure_soilpath_pct = zeros(7, curing_days);

for d = 1:curing_days
    vals = curing_soil(:, d);
    cure_soil_pct(1,d) = min(vals);
    cure_soil_pct(2,d) = prctile(vals, 5);
    cure_soil_pct(3,d) = prctile(vals, 25);
    cure_soil_pct(4,d) = prctile(vals, 50);
    cure_soil_pct(5,d) = prctile(vals, 75);
    cure_soil_pct(6,d) = prctile(vals, 95);
    cure_soil_pct(7,d) = max(vals);
    
    vals = curing_irrig(:, d);
    cure_irrig_pct(1,d) = min(vals);
    cure_irrig_pct(2,d) = prctile(vals, 5);
    cure_irrig_pct(3,d) = prctile(vals, 25);
    cure_irrig_pct(4,d) = prctile(vals, 50);
    cure_irrig_pct(5,d) = prctile(vals, 75);
    cure_irrig_pct(6,d) = prctile(vals, 95);
    cure_irrig_pct(7,d) = max(vals);
    
    vals = curing_soilpath(:, d);
    cure_soilpath_pct(1,d) = min(vals);
    cure_soilpath_pct(2,d) = prctile(vals, 5);
    cure_soilpath_pct(3,d) = prctile(vals, 25);
    cure_soilpath_pct(4,d) = prctile(vals, 50);
    cure_soilpath_pct(5,d) = prctile(vals, 75);
    cure_soilpath_pct(6,d) = prctile(vals, 95);
    cure_soilpath_pct(7,d) = max(vals);
end

fprintf('  Percentile computation complete.\n');

% same plot styling as section 8.5
pct_labels = {'Min', '5th Percentile', '25th Percentile', ...
              '50th Percentile (Median)', '75th Percentile', ...
              '95th Percentile', 'Max'};

pct_colors = [0.6 0.6 0.6;   ...
              0.0 0.6 0.9;   ...
              0.0 0.3 0.7;   ...
              0.9 0.0 0.0;   ...
              1.0 0.5 0.0;   ...
              0.6 0.0 0.6;   ...
              0.2 0.2 0.2];

pct_styles = {':', '--', '-.', '-', '-.', '--', ':'};
pct_widths = [1.0, 1.2, 1.5, 2.5, 1.5, 1.2, 1.0];

x_days = -27:0;
x_labels_desc = 27:-1:0;

% Figure 16: soil CFU during curing
figure(16); clf;

for p = 1:7
    plot(x_days, log10(cure_soil_pct(p,:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), ...
        'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end

fill([x_days, fliplr(x_days)], ...
     [log10(cure_soil_pct(5,:)+1), fliplr(log10(cure_soil_pct(3,:)+1))], ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([x_days, fliplr(x_days)], ...
     [log10(cure_soil_pct(6,:)+1), fliplr(log10(cure_soil_pct(2,:)+1))], ...
     [0.5 0.2 0.7], 'FaceAlpha', 0.06, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;

xline(-14, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Irrigation Stop');

xlabel('Days Relative to Harvest (0 = Harvest Day)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Soil E. coli During 28-Day Curing Period', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on; xlim([-27 0]);
set(gca, 'XTick', -27:3:0);
fprintf('  Figure 16 created: Soil CFU during curing period\n');

%% ========================================================================
%  SECTION 10B: ONION SURFACE - BULBING TO HARVEST
%% ========================================================================
% onion surface CFU from bulbing start through harvest
% phase 1: both pathways active (bulbing -> irr stop)
% phase 2: irr residual decays + soil transfer continues (irr stop -> harvest)
fprintf('\n========== ONION SURFACE E. COLI: BULBING TO HARVEST ==========\n');

bulbing_day = plant1 + bulb_start;
irr_stop_day = har1 - irr_stop;
days_bulb_to_harvest = har1 - bulbing_day;

max_duration = max(days_bulb_to_harvest);

fprintf('  Bulbing start range: Day %d to %d\n', min(bulbing_day), max(bulbing_day));
fprintf('  Irrigation stop range: Day %d to %d\n', min(irr_stop_day), max(irr_stop_day));
fprintf('  Harvest range: Day %d to %d\n', min(har1), max(har1));
fprintf('  Bulb-to-harvest duration: %d to %d days (max window = %d)\n', ...
    min(days_bulb_to_harvest), max(days_bulb_to_harvest), max_duration);

% NaN padding for iterations with shorter growing windows
onion_surface_daily = NaN(iterations, max_duration);
onion_irrig_component = NaN(iterations, max_duration);
onion_soilpath_component = NaN(iterations, max_duration);

fprintf('  Building onion surface matrix [%d x %d]...\n', iterations, max_duration);

for i = 1:iterations
    n_days = days_bulb_to_harvest(i);
    irr_stop_offset = irr_stop_day(i) - bulbing_day(i);
    
    last_irrig_cfu = 0;
    
    for d = 1:n_days
        actual_day = bulbing_day(i) + d - 1;
        day_idx = mod(actual_day - 1, 365) + 1;
        
        irrig_per_plant = squeeze(CFU_irrigation_plant_daily(i, :, day_idx));
        soilpath_per_plant = squeeze(CFU_soil_pathway_plant_daily(i, :, day_idx));
        
        mean_irrig = mean(irrig_per_plant);
        mean_soilpath = mean(soilpath_per_plant);
        
        if d <= irr_stop_offset
            % phase 1: both active
            onion_irrig_component(i, d) = mean_irrig;
            onion_soilpath_component(i, d) = mean_soilpath;
            last_irrig_cfu = mean_irrig;
        else
            % phase 2: irrigation stopped, residual decays
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            last_irrig_cfu = 10^(log10(last_irrig_cfu + 1e-10) + monthly_decay(month));
            
            onion_irrig_component(i, d) = last_irrig_cfu;
            onion_soilpath_component(i, d) = mean_soilpath;
        end
        
        onion_surface_daily(i, d) = onion_irrig_component(i, d) + onion_soilpath_component(i, d);
    end
    
    if mod(i, 50) == 0
        fprintf('    Iteration %d/%d complete\n', i, iterations);
    end
end

fprintf('  Onion surface matrix complete.\n');

% percentiles ignoring NaN from shorter iterations
surface_pct = NaN(7, max_duration);

for d = 1:max_duration
    vals = onion_surface_daily(:, d);
    vals = vals(~isnan(vals));
    
    if ~isempty(vals)
        surface_pct(1,d) = min(vals);
        surface_pct(2,d) = prctile(vals, 5);
        surface_pct(3,d) = prctile(vals, 25);
        surface_pct(4,d) = prctile(vals, 50);
        surface_pct(5,d) = prctile(vals, 75);
        surface_pct(6,d) = prctile(vals, 95);
        surface_pct(7,d) = max(vals);
    end
end

fprintf('  Percentile computation complete.\n');

irr_stop_offsets = irr_stop_day - bulbing_day;
median_irr_stop = median(irr_stop_offsets);
fprintf('  Irrigation stop offset: median = %.0f days after bulbing\n', median_irr_stop);

pct_labels = {'Min', '5th Percentile', '25th Percentile', ...
              '50th Percentile (Median)', '75th Percentile', ...
              '95th Percentile', 'Max'};

pct_colors = [0.6 0.6 0.6;   ...
              0.0 0.6 0.9;   ...
              0.0 0.3 0.7;   ...
              0.9 0.0 0.0;   ...
              1.0 0.5 0.0;   ...
              0.6 0.0 0.6;   ...
              0.2 0.2 0.2];

pct_styles = {':', '--', '-.', '-', '-.', '--', ':'};
pct_widths = [1.0, 1.2, 1.5, 2.5, 1.5, 1.2, 1.0];

x_days = 1:max_duration;

% Figure 17: main onion surface plot
figure(17); clf;

for p = 1:7
    plot(x_days, log10(surface_pct(p,:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), ...
        'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end

valid = ~isnan(surface_pct(3,:)) & ~isnan(surface_pct(5,:));
if any(valid)
    vd = find(valid);
    fill([vd, fliplr(vd)], ...
         [log10(surface_pct(5,vd)+1), fliplr(log10(surface_pct(3,vd)+1))], ...
         [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

valid2 = ~isnan(surface_pct(2,:)) & ~isnan(surface_pct(6,:));
if any(valid2)
    vd2 = find(valid2);
    fill([vd2, fliplr(vd2)], ...
         [log10(surface_pct(6,vd2)+1), fliplr(log10(surface_pct(2,vd2)+1))], ...
         [0.5 0.2 0.7], 'FaceAlpha', 0.06, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

xline(median_irr_stop, 'k--', 'LineWidth', 1.8, 'DisplayName', ...
    sprintf('Irrigation Stop (~Day %d)', round(median_irr_stop)));

text(median_irr_stop/2, max(log10(surface_pct(7,:)+1)) * 0.95, ...
    'Phase 1: Irrigation + Soil Transfer', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold', ...
    'Color', [0 0.4 0.7]);
text(median_irr_stop + (max_duration - median_irr_stop)/2, ...
    max(log10(surface_pct(7,:)+1)) * 0.95, ...
    'Phase 2: Residual Irrig. Decay + Soil Transfer', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold', ...
    'Color', [0.7 0.3 0]);

hold off;

xlabel('Days Since Bulbing Start', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Onion Surface E. coli: Bulbing Start to Harvest', ...
      'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on;
xlim([1 max_duration]);
fprintf('  Figure 17 created: Onion surface E. coli bulbing to harvest\n');

% Figure 18: pathway decomposition
figure(18); clf;

median_irrig_comp = zeros(1, max_duration);
median_soilpath_comp = zeros(1, max_duration);
median_total = zeros(1, max_duration);

for d = 1:max_duration
    v1 = onion_irrig_component(:, d);
    v1 = v1(~isnan(v1));
    if ~isempty(v1), median_irrig_comp(d) = median(v1); end
    
    v2 = onion_soilpath_component(:, d);
    v2 = v2(~isnan(v2));
    if ~isempty(v2), median_soilpath_comp(d) = median(v2); end
    
    v3 = onion_surface_daily(:, d);
    v3 = v3(~isnan(v3));
    if ~isempty(v3), median_total(d) = median(v3); end
end

plot(x_days, log10(median_total + 1), 'k-', 'LineWidth', 2.5, ...
    'DisplayName', 'Total Onion Surface');
hold on;

xline(median_irr_stop, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Irrigation Stop');
hold off;

xlabel('Days Since Bulbing Start', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Pathway Decomposition: Median Onion Surface CFU', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
xlim([1 max_duration]);
fprintf('  Figure 18 created: Pathway decomposition\n');

fprintf('\n--- Onion Surface CFU Summary (Median across iterations) ---\n');
fprintf('  %-30s  %12s  %12s  %12s\n', '', 'Bulbing Start', 'Irr Stop', 'Harvest');
fprintf('  %s\n', repmat('-', 1, 70));

irr_idx = round(median_irr_stop);
fprintf('  %-30s  %12.4f  %12.4f  %12.4f\n', 'Total Surface (median)', ...
    surface_pct(4,1), surface_pct(4,irr_idx), surface_pct(4,max_duration));
fprintf('  %-30s  %12.4f  %12.4f  %12.4f\n', 'Irrigation Component', ...
    median_irrig_comp(1), median_irrig_comp(irr_idx), median_irrig_comp(max_duration));
fprintf('  %-30s  %12.4f  %12.4f  %12.4f\n', 'Soil Transfer Component', ...
    median_soilpath_comp(1), median_soilpath_comp(irr_idx), median_soilpath_comp(max_duration));


%% ========================================================================
%  SECTION 11: THRESHOLD EXCEEDANCE DURING CURING
%% ========================================================================
% count plants above thresholds on the onion surface for each of the 28 curing days
fprintf('\n========== PLANTS EXCEEDING THRESHOLDS - 28-DAY CURING ==========\n');

%thresholds = [10, 20, 50, 100];
thresholds = [1, 5, 10, 20];
n_thresh = length(thresholds);
curing_days = 28;

plants_exceed = zeros(iterations, curing_days, n_thresh);

fprintf('  Computing plant counts for %d iterations x %d days x %d thresholds...\n', ...
    iterations, curing_days, n_thresh);

for i = 1:iterations
    for d = 1:curing_days
        actual_day = har1(i) - (curing_days - d);
        day_idx = mod(actual_day - 1, 365) + 1;
        
        % combine both pathways
        onion_surface_cfu = squeeze(CFU_irrigation_plant_daily(i, :, day_idx)) + ...
                            squeeze(CFU_soil_pathway_plant_daily(i, :, day_idx));
        
        for t = 1:n_thresh
            plants_exceed(i, d, t) = sum(onion_surface_cfu > thresholds(t));
        end
    end
    
    if mod(i, 50) == 0
        fprintf('    Iteration %d/%d complete\n', i, iterations);
    end
end

mean_plants_exceed = zeros(curing_days, n_thresh);
for d = 1:curing_days
    for t = 1:n_thresh
        mean_plants_exceed(d, t) = mean(plants_exceed(:, d, t));
    end
end

x_days = -27:0;

% Figure 20
figure(20); clf;

thresh_colors = [0.0 0.5 0.0;   ...
                 0.0 0.4 0.8;   ...
                 0.9 0.5 0.0;   ...
                 0.8 0.0 0.0];
thresh_styles = {'-o', '-s', '-d', '-^'};

for t = 1:n_thresh
    plot(x_days, mean_plants_exceed(:, t), thresh_styles{t}, ...
        'Color', thresh_colors(t,:), 'LineWidth', 2, ...
        'MarkerSize', 4, 'MarkerFaceColor', thresh_colors(t,:), ...
        'DisplayName', sprintf('> %d CFU', thresholds(t)));
    if t == 1, hold on; end
end

xline(-14, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Irrigation Stop');
hold off;

xlabel('Days Relative to Harvest (0 = Harvest Day)', 'FontSize', 12);
ylabel('Mean Number of Plants Exceeding Threshold', 'FontSize', 12);
title('Mean Plants Exceeding E. coli Thresholds on Onion Surface - 28-Day Curing', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
xlim([-27 0]);
set(gca, 'XTick', -27:3:0);

fprintf('\n--- Mean Plants Exceeding Thresholds (out of %d) ---\n', plantnum);
fprintf('%-12s', 'Day');
for t = 1:n_thresh
    fprintf('  >%4d CFU', thresholds(t));
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 55));
report_days = [1, 7, 14, 21, 28];
for rd = report_days
    day_label = -(curing_days - rd);
    fprintf('Day %4d    ', day_label);
    for t = 1:n_thresh
        fprintf('  %9.1f', mean_plants_exceed(rd, t));
    end
    fprintf('\n');
end

fprintf('\n--- As Percentage of Total Plants ---\n');
fprintf('%-12s', 'Day');
for t = 1:n_thresh
    fprintf('  >%4d CFU', thresholds(t));
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 55));
for rd = report_days
    day_label = -(curing_days - rd);
    fprintf('Day %4d    ', day_label);
    for t = 1:n_thresh
        fprintf('  %8.4f%%', mean_plants_exceed(rd, t) / plantnum * 100);
    end
    fprintf('\n');
end

fprintf('\n========== CURING THRESHOLD ANALYSIS COMPLETE ==========\n');

%% ========================================================================
%  SECTION 9: EXPORT TO JSON
%% ========================================================================
%  Writes baseline.json to ./export/ - the reference (100%/100%) scenario.
%  Uses the same 7-band fan structure (Min/P5/P25/P50/P75/P95/Max) as the
%  SA_wildlife_*/SA_irrig_* matrices exported from File 2, so that baseline
%  and sensitivity scenarios can be overlaid consistently in the dashboard.
%% ========================================================================
fprintf('\n========== EXPORTING TO JSON ==========\n');

% --- set export directory using absolute path ---
export_dir = fullfile(pwd, 'export');
fprintf('  Export directory: %s\n', export_dir);

if ~exist(export_dir, 'dir')
    [status, msg] = mkdir(export_dir);
    if status == 0
        error('Could not create export directory: %s\nReason: %s', export_dir, msg);
    end
    fprintf('  Created export/ folder.\n');
else
    fprintf('  export/ folder already exists.\n');
end

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

collapse_row_to_monthly = @(daily_row) arrayfun(@(m) ...
    mean(daily_row((month_boundaries(m)+1):month_boundaries(m+1))), 1:12);

fprintf('  Writing baseline.json...\n');

baseline_data = struct();
baseline_data.parameter = 'baseline';

% --- daily 7-band fan (soil CFU) — Fig 9 ---
baseline_data.daily.min = soil_pct(1,:);
baseline_data.daily.p05 = soil_pct(2,:);
baseline_data.daily.p25 = soil_pct(3,:);
baseline_data.daily.p50 = soil_pct(4,:);
baseline_data.daily.p75 = soil_pct(5,:);
baseline_data.daily.p95 = soil_pct(6,:);
baseline_data.daily.max = soil_pct(7,:);

% --- monthly 7-band fan (soil CFU) ---
baseline_data.monthly.min = collapse_row_to_monthly(soil_pct(1,:));
baseline_data.monthly.p05 = collapse_row_to_monthly(soil_pct(2,:));
baseline_data.monthly.p25 = collapse_row_to_monthly(soil_pct(3,:));
baseline_data.monthly.p50 = collapse_row_to_monthly(soil_pct(4,:));
baseline_data.monthly.p75 = collapse_row_to_monthly(soil_pct(5,:));
baseline_data.monthly.p95 = collapse_row_to_monthly(soil_pct(6,:));
baseline_data.monthly.max = collapse_row_to_monthly(soil_pct(7,:));

% --- monthly pathway breakdown --- Fig 3, Fig 5 ---
baseline_data.monthly.irrigationPathway = mean(CFU_irrigation_monthly_avg, 1);
baseline_data.monthly.soilPathway       = mean(CFU_soil_pathway_monthly_avg, 1);
baseline_data.monthly.months            = months;

% --- monthly stats by harvest month --- Fig 2, Fig 3 ---
baseline_data.monthly.meanCrop1       = Mean_crop1(:)';
baseline_data.monthly.meanIrrigation  = Mean_irrigation(:)';
baseline_data.monthly.meanSoil        = Mean_soil(:)';
baseline_data.monthly.prevalencePct   = Prevalence_crop1(:)';

% --- summary scalars ---
% Year-round soil (CFU_daily) vs harvest onion-surface (CFU_crop1) are separate KPIs.
baseline_data.summary.meanCFU              = mean(CFU_daily(:));
baseline_data.summary.medianSoilCFU        = median(CFU_daily(:));
baseline_data.summary.medianOnionCFU       = median(CFU_crop1(:));
baseline_data.summary.medianCFU            = median(CFU_crop1(:));  % dashboard headline KPI
baseline_data.summary.maxCFU               = max(CFU_daily(:));
baseline_data.summary.stdCFU               = std(CFU_daily(:));
baseline_data.summary.lod                  = LOD;
baseline_data.summary.overallPrevalencePct = sum(CFU_crop1(:) >= LOD) / numel(CFU_crop1) * 100;
baseline_data.summary.totalPlants          = plantnum;
baseline_data.summary.iterations           = iterations;

% --- pathway contribution ---
baseline_data.pathwayContribution.irrigationPct = irrigation_contribution;
baseline_data.pathwayContribution.soilPct       = soil_contribution;

% --- Fig 10: irrigation pathway daily percentile fan ---
baseline_data.irrigationDaily.min = irrig_pct(1,:);
baseline_data.irrigationDaily.p05 = irrig_pct(2,:);
baseline_data.irrigationDaily.p25 = irrig_pct(3,:);
baseline_data.irrigationDaily.p50 = irrig_pct(4,:);
baseline_data.irrigationDaily.p75 = irrig_pct(5,:);
baseline_data.irrigationDaily.p95 = irrig_pct(6,:);
baseline_data.irrigationDaily.max = irrig_pct(7,:);

% --- Fig 11/7: soil transfer pathway daily percentile fan ---
baseline_data.soilPathwayDaily.min = soilpath_pct(1,:);
baseline_data.soilPathwayDaily.p05 = soilpath_pct(2,:);
baseline_data.soilPathwayDaily.p25 = soilpath_pct(3,:);
baseline_data.soilPathwayDaily.p50 = soilpath_pct(4,:);
baseline_data.soilPathwayDaily.p75 = soilpath_pct(5,:);
baseline_data.soilPathwayDaily.p95 = soilpath_pct(6,:);
baseline_data.soilPathwayDaily.max = soilpath_pct(7,:);

% --- Fig 12/13: threshold exceedance mean by harvest month ---
baseline_thresh = zeros(12, length(thresholds));
for m = 1:12
    for t = 1:length(thresholds)
        data = monthly_plant_counts{m, t};
        if ~isempty(data)
            baseline_thresh(m, t) = mean(data);
        end
    end
end
baseline_data.thresholdByMonth.thresholds   = thresholds;
baseline_data.thresholdByMonth.mean         = baseline_thresh;
baseline_data.thresholdByMonth.meanPct      = baseline_thresh / plantnum * 100;
baseline_data.thresholdByMonth.months       = months;
baseline_data.thresholdByMonth.activeMonths = months(any(baseline_thresh > 0, 2));

% --- Fig 14: threshold exceedance quartiles by harvest month ---
thresh_q = zeros(12, length(thresholds), 4);  % [month x thresh x stat]
for m = 1:12
    for t = 1:length(thresholds)
        data = monthly_plant_counts{m, t};
        if ~isempty(data)
            thresh_q(m, t, 1) = prctile(data, 25);
            thresh_q(m, t, 2) = median(data);
            thresh_q(m, t, 3) = prctile(data, 75);
            thresh_q(m, t, 4) = max(data);
        end
    end
end
baseline_data.thresholdByMonth.quartiles      = thresh_q;
baseline_data.thresholdByMonth.quartileLabels = {'p25','median','p75','max'};

% --- Fig 15: curing decay fit samples (up to 10 curves) ---
n_cure_export = min(10, iterations);
baseline_data.curingDecay.slopes      = curing_slope(1:n_cure_export)';
baseline_data.curingDecay.intercepts  = curing_intercept(1:n_cure_export)';
baseline_data.curingDecay.timePoints  = curing_time_points;
baseline_data.curingDecay.sampledMPN  = curing_sampled_mpn(1:n_cure_export, :);

% --- Fig 16: soil CFU during 28-day curing window ---
baseline_data.curingPeriod.soilCFU.min            = cure_soil_pct(1,:);
baseline_data.curingPeriod.soilCFU.p05            = cure_soil_pct(2,:);
baseline_data.curingPeriod.soilCFU.p25            = cure_soil_pct(3,:);
baseline_data.curingPeriod.soilCFU.p50            = cure_soil_pct(4,:);
baseline_data.curingPeriod.soilCFU.p75            = cure_soil_pct(5,:);
baseline_data.curingPeriod.soilCFU.p95            = cure_soil_pct(6,:);
baseline_data.curingPeriod.soilCFU.max            = cure_soil_pct(7,:);
baseline_data.curingPeriod.daysRelativeToHarvest  = -27:0;

% --- Fig 20: plants exceeding thresholds during 28-day curing ---
baseline_data.curingPeriod.thresholdExceedance.mean       = mean_plants_exceed;
baseline_data.curingPeriod.thresholdExceedance.meanPct    = mean_plants_exceed / plantnum * 100;
baseline_data.curingPeriod.thresholdExceedance.thresholds = thresholds;
baseline_data.curingPeriod.thresholdExceedance.daysRelativeToHarvest = -27:0;

% --- Fig 17: onion surface percentile fan from bulbing to harvest ---
baseline_data.onionSurface.min           = surface_pct(1,:);
baseline_data.onionSurface.p05           = surface_pct(2,:);
baseline_data.onionSurface.p25           = surface_pct(3,:);
baseline_data.onionSurface.p50           = surface_pct(4,:);
baseline_data.onionSurface.p75           = surface_pct(5,:);
baseline_data.onionSurface.p95           = surface_pct(6,:);
baseline_data.onionSurface.max           = surface_pct(7,:);
baseline_data.onionSurface.maxDuration   = max_duration;
baseline_data.onionSurface.medianIrrStop = median_irr_stop;

% --- Fig 18: pathway decomposition on onion surface ---
baseline_data.onionSurface.medianTotal     = median_total;
baseline_data.onionSurface.medianIrrigComp = median_irrig_comp;
baseline_data.onionSurface.medianSoilComp  = median_soilpath_comp;

% --- Fig 1: contamination distribution histograms ---
irrig_pos = CFU_onion_survival(CFU_onion_survival > 0);
soil_pos   = CFU_soil_pathway(CFU_soil_pathway > 0);
comb_pos   = CFU_crop1(CFU_crop1 > 0);

if ~isempty(irrig_pos)
    [irrig_counts, irrig_edges] = histcounts(log10(irrig_pos + 1e-10), 30);
    baseline_data.histograms.irrigationLog10.counts = irrig_counts;
    baseline_data.histograms.irrigationLog10.edges  = irrig_edges;
else
    baseline_data.histograms.irrigationLog10.counts = zeros(1,30);
    baseline_data.histograms.irrigationLog10.edges  = linspace(-10, 0, 31);
end

if ~isempty(soil_pos)
    [soil_counts, soil_edges] = histcounts(log10(soil_pos + 1e-10), 30);
    baseline_data.histograms.soilLog10.counts = soil_counts;
    baseline_data.histograms.soilLog10.edges  = soil_edges;
else
    baseline_data.histograms.soilLog10.counts = zeros(1,30);
    baseline_data.histograms.soilLog10.edges  = linspace(-10, 0, 31);
end

if ~isempty(comb_pos)
    [comb_counts, comb_edges] = histcounts(log10(comb_pos + 1e-10), 30);
    baseline_data.histograms.combinedLog10.counts = comb_counts;
    baseline_data.histograms.combinedLog10.edges  = comb_edges;
else
    baseline_data.histograms.combinedLog10.counts = zeros(1,30);
    baseline_data.histograms.combinedLog10.edges  = linspace(-10, 0, 31);
end

% --- write file ---
outpath = fullfile(export_dir, 'baseline.json');
fid = fopen(outpath, 'w');
if fid == -1
    error('fopen failed — could not open file for writing: %s\nCheck that the export directory exists and is writable.', outpath);
end
fwrite(fid, jsonencode(baseline_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

fprintf('\n========== JSON EXPORT COMPLETE ==========\n');
fprintf('  File written to: %s\n', export_dir);
fprintf('  (5 sensitivity/prevalence files are exported separately by File 2)\n');

% --- verification ---
fprintf('\n=== baseline.json STRUCTURE VERIFICATION ===\n');
b = jsondecode(fileread(outpath));
fprintf('\nTop-level fields:\n');           disp(fieldnames(b))
fprintf('daily.p50 size: %dx%d\n',          size(b.daily.p50));
fprintf('irrigationDaily.p50 size: %dx%d\n', size(b.irrigationDaily.p50));
fprintf('soilPathwayDaily.p50 size: %dx%d\n', size(b.soilPathwayDaily.p50));
fprintf('thresholdByMonth.mean size: %dx%d\n', size(b.thresholdByMonth.mean));
fprintf('thresholdByMonth.thresholds: ');   disp(b.thresholdByMonth.thresholds)
fprintf('curingPeriod soilCFU.p50 size: %dx%d\n', size(b.curingPeriod.soilCFU.p50));
fprintf('curingPeriod thresh.mean size: %dx%d\n',  size(b.curingPeriod.thresholdExceedance.mean));
fprintf('onionSurface.p50 size: %dx%d\n',   size(b.onionSurface.p50));
fprintf('onionSurface.maxDuration: %d\n',   b.onionSurface.maxDuration);
fprintf('curingDecay.slopes size: %dx%d\n', size(b.curingDecay.slopes));
fprintf('histograms.irrigationLog10.counts size: %dx%d\n', size(b.histograms.irrigationLog10.counts));
fprintf('summary.medianSoilCFU: %.4e\n',     b.summary.medianSoilCFU);
fprintf('summary.medianOnionCFU: %.4e\n',   b.summary.medianOnionCFU);
fprintf('summary.medianCFU (onion KPI): %.4e\n', b.summary.medianCFU);
fprintf('pathwayContribution.irrigationPct: %.1f%%\n', b.pathwayContribution.irrigationPct);
fprintf('\n=== VERIFICATION COMPLETE ===\n');




%% ========================================================================
%  SECTION 10: SAVE ALL FIGURES AS .FIG AND .PNG
%% ========================================================================
fprintf('\n========== SAVING FIGURES ==========\n');

% --- create output directories ---
fig_dir     = fullfile(pwd, 'figures');
fig_dir_png = fullfile(fig_dir, 'png');
fig_dir_fig = fullfile(fig_dir, 'fig');

for d = {fig_dir, fig_dir_png, fig_dir_fig}
    if ~exist(d{1}, 'dir')
        mkdir(d{1});
    end
end
fprintf('  PNG output: %s\n', fig_dir_png);
fprintf('  FIG output: %s\n', fig_dir_fig);

% --- build figure list ---
fig_list = { ...
     1,  'pathway_distributions'; ...
     2,  'monthly_prevalence'; ...
     3,  'pathway_contribution_by_month'; ...
     4,  'daily_soil_cfu_trend'; ...
     5,  'irrigation_pathway_timeseries'; ...
     6,  'pathway_comparison_3panel'; ...
     7,  'soil_pathway_detail'; ...
     8,  'combined_3panel_overview'; ...
     9,  'soil_cfu_daily_percentiles'; ...
    10,  'irrigation_daily_percentiles'; ...
    11,  'soil_transfer_daily_percentiles'; ...
    12,  'plants_exceeding_thresholds_bar'; ...
    13,  'plants_exceeding_thresholds_pct'; ...
    14,  'plants_exceeding_box_plots'; ...
    15,  'curing_decay_fits'; ...
    16,  'soil_cfu_curing_period'; ...
    17,  'onion_surface_bulbing_to_harvest'; ...
    18,  'pathway_decomposition_onion_surface'; ...
    20,  'plants_exceeding_curing_28day'; ...
};

% --- save each figure ---
n_saved_png = 0;
n_saved_fig = 0;
n_skipped   = 0;

for f = 1:size(fig_list, 1)
    fig_num  = fig_list{f, 1};
    fig_name = fig_list{f, 2};
    base_name = sprintf('fig%02d_%s', fig_num, fig_name);

    if ishandle(fig_num)
        fh = figure(fig_num);

        % save PNG
        png_path = fullfile(fig_dir_png, [base_name, '.png']);
        try
            exportgraphics(fh, png_path, 'Resolution', 150);
            n_saved_png = n_saved_png + 1;
            fprintf('  PNG saved: %s\n', base_name);
        catch ME
            fprintf('  WARNING PNG: Figure %d failed: %s\n', fig_num, ME.message);
        end

        % save .fig (fully interactive MATLAB figure file)
        fig_path = fullfile(fig_dir_fig, [base_name, '.fig']);
        try
            savefig(fh, fig_path, 'compact');
            n_saved_fig = n_saved_fig + 1;
            fprintf('  FIG saved: %s\n', base_name);
        catch ME
            fprintf('  WARNING FIG: Figure %d failed: %s\n', fig_num, ME.message);
        end

    else
        fprintf('  Skipped Figure %d (not in memory)\n', fig_num);
        n_skipped = n_skipped + 1;
    end
end

fprintf('\n  PNG files saved: %d\n', n_saved_png);
fprintf('  FIG files saved: %d\n', n_saved_fig);
fprintf('  Figures skipped: %d\n', n_skipped);
fprintf('  Total figures attempted: %d\n', size(fig_list, 1));
fprintf('\n========== FIGURE SAVING COMPLETE ==========\n');



%% ========================================================================
%  HELPER FUNCTIONS
%% ========================================================================

function pond_cfu = calculate_pond_concentration(source_cfu_100ml, wildlife_runoff_cfu, pond_volume_L)
    source_total_cfu = source_cfu_100ml * (pond_volume_L / 100);
    total_cfu = source_total_cfu + wildlife_runoff_cfu;
    pond_cfu = total_cfu / (pond_volume_L / 100);
end


function moisture_daily = generate_moisture_profile(year_days, rainfall_monthly)
    moisture_daily = zeros(1, year_days);
    for day = 1:year_days
        month = ceil(day / 30.5);
        if month > 12, month = 12; end

        base_moisture = 5 + rainfall_monthly(month) / 20;
        moisture_daily(day) = base_moisture + randn() * 1.5;
        moisture_daily(day) = max(2, min(13, moisture_daily(day)));
    end
end

function cw = sample_IrrigationSource1(n)
    % lognormal(2.1, 0.4), GM=126 CFU/100mL, STV=410
    pd = makedist('Lognormal', 2.1, 0.4);
    cw = random(pd, n, 1);
end




function cw = sample_IrrigationSource2(n)
    % subsurface source - triangular distribution
    
    a_min = 0.0011;
    
    mu_dist = makedist('Triangular', 'a', 3.5, 'b', 119.985, 'c', 236.47);
    mu = random(mu_dist, n, 1);
    
    b_dist = makedist('Triangular', 'a', 9.47, 'b', 1505.235, 'c', 3001.0);
    b_max = random(b_dist, n, 1);
    
    % mode = 3*mean - (min + max)
    mode = 3*mu - (a_min + b_max);
    
    mode = min(max(mode, a_min + 1e-9), b_max - 1e-9);
    
    td = makedist('Triangular', 'a', a_min, 'b', mode, 'c', b_max);
    
    cw = random(td, n, 1);
end

function cfu_gain = calculate_rainfall_cfu_gain(rainfall_mm)
    % empirical regression: delta_E = 0.0824R - 0.0011R^2
    R = rainfall_mm;
    delta_E = 0.0824 * R - 0.0011 * R^2;
    
    cfu_gain = max(0, delta_E);  % floor at zero
    
    % cfu_gain = min(cfu_gain, 100);  % cap not used
end

function irr_schedule = onion_irrig_days(plantDay, harvestDay, bulbStart, irr_stop, ival)
    % build irrigation schedule from growth stages
    irr_schedule = struct('doy', {}, 'stage', {});
    k = plantDay;
    idx = 0;

    while k < harvestDay
        dap = k - plantDay;
        total = harvestDay - plantDay;

        if dap <= 14
            iv = ival.Establish;
            stage = 'Establish';
        elseif dap <= bulbStart
            iv = ival.Veg;
            stage = 'Veg';
        elseif dap < (total - irr_stop)
            iv = ival.Bulb;
            stage = 'Bulb';
        else
            break;
        end

        idx = idx + 1;
        irr_schedule(idx).doy = k;
        irr_schedule(idx).stage = stage;
        k = k + iv;
    end
end

function depth_in = depth_for_stage(stage, depth)
    switch stage
        case 'Establish'
            depth_in = depth.Establish;
        case 'Veg'
            depth_in = depth.Veg;
        case 'Bulb'
            % Sample per event from PERT(min, mode, max) via Beta
            depth_in = depth.BulbMin + (depth.BulbMax - depth.BulbMin) * random(depth.BulbBeta, 1);
        otherwise
            depth_in = 0;
    end
end

function subplot_cfu = distribute_wildlife_to_subplots(CFU_total, num_subplots, contamination_type)
    subplot_cfu = zeros(num_subplots, 1);
    
    if strcmp(contamination_type, 'localized')
        % concentrated in 10% of plants
        num_affected = ceil(0.1 * num_subplots);
        affected_plants = randperm(num_subplots, num_affected);
        for s = 1:num_affected
            subplot_cfu(affected_plants(s)) = CFU_total / num_affected;
        end
    else % uniform
        subplot_cfu(:) = CFU_total / num_subplots;
    end
end


function trans = transferfn(val)
    % piecewise linear transfer (not used in main model currently)
    if val <= 0.619
        trans = 1.3 * (val - 0) / (0.619 - 0);
    elseif val >= 0.619 && val <= 0.946
        trans = 1.3 + ((340 - 1.3) * (val - 0.619) / (0.946 - 0.619));
    else
        trans = 340 + ((230000 - 340) * (val - 0.946) / (1 - 0.946));
    end
end


function month = get_month_index_jul_start(day_of_year)
    % day-of-year -> month index (Jul=1, Jun=12)
    month_days = [31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
    
    day_idx = mod(day_of_year - 1, 365) + 1;
    
    month = find(day_idx <= month_days, 1, 'first');
    if isempty(month)
        month = 12;
    end
end