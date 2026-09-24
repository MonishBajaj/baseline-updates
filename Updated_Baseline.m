%% ========================================================================
%  ONION E. COLI CONTAMINATION MODEL
%  ========================================================================
%  Models E.coli contamination from wildlife fecal + irrigation water
%  onto a 1-acre Vidalia onion field. All sources -> soil -> onion surface.


clc; clear; rng(1);

%% ========================================================================
%  SECTION 1: INITIALIZATION & FIELD PARAMETERS
%% ========================================================================
fprintf('\n========= ONION E. COLI CONTAMINATION MODEL ==========\n');
fprintf('Initializing parameters...\n');

iterations = 1000; % Monte Carlo iterations

% crop timing - planting Nov-Dec; stage durations are bounded discrete-uniform
% draws from the onion timeline (weeks converted to days)
% day counts are relative to Jul 1 start
plant1 = unidrnd(61, iterations, 1) + 123;  % Nov-Dec window
establishment_days = randi([14, 28], iterations, 1); % small plants: 2-4 weeks
vegetative_days    = randi([28, 35], iterations, 1); % growing plants: 4-5 weeks
bulb_dev_days      = randi([42, 56], iterations, 1); % bulb development: 6-8 weeks
maturation_days    = randi([7, 14], iterations, 1);  % maturation: 1-2 weeks
bulbing_days       = bulb_dev_days + maturation_days;
bulb_start         = establishment_days + vegetative_days; % DAP, varies by iteration
growth_days        = bulb_start + bulbing_days;             % 91-133 days
har1 = plant1 + growth_days;  % can exceed 365, that's fine

fprintf('  Planting range: Day %d to %d\n', min(plant1), max(plant1));
fprintf('  Growth period: %d to %d days\n', min(growth_days), max(growth_days));
fprintf('  Establishment: %d-%d; vegetative: %d-%d; bulbing: %d-%d days\n', ...
    min(establishment_days), max(establishment_days), ...
    min(vegetative_days), max(vegetative_days), min(bulbing_days), max(bulbing_days));
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

% -------------------------------------------------------------------------
% Irrigation water volume scale (dashboard: irrigationVolumeFactor)
%   Multiplies applied depth in all stages (Establish / Veg / Bulb PERT).
%   1.00 = baseline; 0.75 = 25% reduction; 0.50 = 50% reduction; 0.25 = 75% reduction.
% -------------------------------------------------------------------------
irrigation_volume_factor = 1.00;  % manual: 1.00, 0.75, 0.50, or 0.25
if ~ismember(irrigation_volume_factor, [1.00, 0.75, 0.50, 0.25])
    error('irrigation_volume_factor must be 1.00, 0.75, 0.50, or 0.25');
end
fprintf('  Irrigation volume factor: %.2f (%.0f%% of baseline stage depths)\n', ...
    irrigation_volume_factor, irrigation_volume_factor * 100);

% -------------------------------------------------------------------------
% Irrigation stop vs undercutting vs curing (aligns with dashboard Farm Characteristics)
%   Timeline: last irrigation → undercutting → harvest
%   irr_stop_before_undercut : 0, 7, or 10 days (dashboard irrigationStopDays; default 7)
%   curing_days             : 0, 3, 7, or 14 (dashboard curingDays; manuscript baseline = 14)
% Optional sensitivity (commented): per-iteration curing 7–10 days
%   curing_days_vec = unidrnd(4, iterations, 1) + 6;  % then undercut1 = har1 - curing_days_vec
% -------------------------------------------------------------------------
irr_stop_before_undercut = 7;  % days irrigation stops BEFORE undercutting
if ~ismember(irr_stop_before_undercut, [0, 7, 10])
    error('irr_stop_before_undercut must be 0, 7, or 10');
end
curing_days = 7;  % undercutting → harvest (manuscript / dashboard default)
if ~ismember(curing_days, [0, 3, 7, 14])
    error('curing_days must be 0, 3, 7, or 14');
end
undercut1 = har1 - curing_days;  % undercutting day per iteration
fprintf('  Irrigation stops %d day(s) before undercutting; curing = %d day(s) (undercut→harvest)\n', ...
    irr_stop_before_undercut, curing_days);

% -------------------------------------------------------------------------
% Soil → onion surface transfer window (Pathway 2)
%   soil_transfer_start = 'bulbing'  -> from plant1 + bulb_start through harvest
%   soil_transfer_start = 'undercut' -> legacy: undercutting through harvest only
%   soil_transfer_interval = 1 (daily) or 7 (weekly)
% -------------------------------------------------------------------------
soil_transfer_start = 'bulbing';  % manual: 'bulbing' or 'undercut'
soil_transfer_interval = 1;       % manual: 1 = daily, 7 = weekly
if ~ismember(soil_transfer_start, {'bulbing', 'undercut'})
    error('soil_transfer_start must be ''bulbing'' or ''undercut''');
end
if ~(isscalar(soil_transfer_interval) && ismember(soil_transfer_interval, [1, 7]))
    error('soil_transfer_interval must be 1 (daily) or 7 (weekly)');
end
if soil_transfer_interval == 1
    interval_label = 'daily';
else
    interval_label = 'weekly';
end
fprintf('  Soil→onion transfer: start at %s, %s through harvest\n', ...
    soil_transfer_start, interval_label);

% -------------------------------------------------------------------------
% Surface water quality vs FDA microbial criteria (dashboard: Water Quality)
%   'fda'       -> force every 20-sample set to meet GM ≤ 126 and STV ≤ 410
%                  Lognormal(2.1, 0.4)  ~ median 8 CFU/100mL
%   'non_fda'   -> force every set to have GM > 126 or STV > 410
%                  Lognormal(5.1, 0.4)  ~ median 164 CFU/100mL
%   'unmanaged' -> no compliance target. Each iteration draws an impact
%                  probability p ~ Beta(alpha, beta). Each of the 20 samples
%                  is clean by default, then impacted with chance p.
%                  The resulting set may meet or not meet the limits.
% -------------------------------------------------------------------------
water_quality_scenario = 'fda';  % manual: 'fda', 'non_fda', or 'unmanaged'
unmanaged_impact_alpha = 3;   % Beta shape; mean = alpha/(alpha+beta) = 0.60
unmanaged_impact_beta  = 2;
if ~ismember(water_quality_scenario, {'fda', 'non_fda', 'unmanaged'})
    error('water_quality_scenario must be ''fda'', ''non_fda'', or ''unmanaged''');
end
if ~(isscalar(unmanaged_impact_alpha) && unmanaged_impact_alpha > 0 && ...
     isscalar(unmanaged_impact_beta)  && unmanaged_impact_beta  > 0)
    error('unmanaged_impact_alpha and unmanaged_impact_beta must be positive scalars');
end
unmanaged_impact_mean = unmanaged_impact_alpha / (unmanaged_impact_alpha + unmanaged_impact_beta);

water_meets_fda = strcmp(water_quality_scenario, 'fda');
switch water_quality_scenario
    case 'fda'
        fprintf('  Surface water scenario: FDA-targeted (every set meets GM≤126 and STV≤410)\n');
    case 'non_fda'
        fprintf('  Surface water scenario: non-FDA-targeted (every set has GM>126 or STV>410)\n');
    case 'unmanaged'
        fprintf(['  Surface water scenario: unmanaged ', ...
            '(p~Beta(%.1f,%.1f) per iteration, mean %.0f%%; outcome not forced)\n'], ...
            unmanaged_impact_alpha, unmanaged_impact_beta, unmanaged_impact_mean * 100);
end

% -------------------------------------------------------------------------
% Wildlife intrusion schedule (manual switch)
%   use_intrusion_schedule = false -> wildlife every day (ignores intrusion_interval)
%   use_intrusion_schedule = true  -> visit only every intrusion_interval days
%   Each visit drops the normal daily feces amount (monthly/30).
%   Fewer visits => less total feces on the field (totals are NOT conserved).
%   Set intrusion_interval to 1, 3, or 7 (every day / every 3 days / every 7 days).
% -------------------------------------------------------------------------
use_intrusion_schedule = true;
intrusion_interval     = 1;   % manual: 1, 3, or 7
if use_intrusion_schedule
    if ~(isscalar(intrusion_interval) && ismember(intrusion_interval, [1, 3, 7]))
        error('intrusion_interval must be 1, 3, or 7 when use_intrusion_schedule is true');
    end
    fprintf('  Wildlife intrusion schedule: ON (every %d day(s); dose = normal daily amount)\n', ...
        intrusion_interval);
else
    fprintf('  Wildlife intrusion schedule: OFF (daily continuous deposition)\n');
end

% -------------------------------------------------------------------------
% Feces deposit locations (manual switch)
%   Number of randomly chosen plant locations that receive each pooping event.
%   Total CFU per event is conserved: each affected plant gets CFU_total / N.
%   Set feces_deposit_locations to 1 or 9.
% -------------------------------------------------------------------------
feces_deposit_locations = 1;  % manual: 1 or 9
if ~ismember(feces_deposit_locations, [1, 9])
    error('feces_deposit_locations must be 1 or 9');
end
fprintf('  Feces deposit locations: %d (total CFU conserved per pooping event)\n', ...
    feces_deposit_locations);

% -------------------------------------------------------------------------
% Wildlife type (manual switch)
%   wildlife_type = 'deer' -> white-tailed deer feces only
%   wildlife_type = 'boar' -> wild boar feces only
%   wildlife_type = 'both' -> deer + wild boar (manuscript / dashboard default)
%   Drives the full baseline (soil → onion → prevalence → JSON).
% -------------------------------------------------------------------------
wildlife_type = 'both';  % manual: 'deer', 'boar', or 'both'
if ~ismember(wildlife_type, {'deer', 'boar', 'both'})
    error('wildlife_type must be ''deer'', ''boar'', or ''both''');
end
switch wildlife_type
    case 'deer'
        wl_deer_factor = 1;  wl_boar_factor = 0;
    case 'boar'
        wl_deer_factor = 0;  wl_boar_factor = 1;
    otherwise  % 'both'
        wl_deer_factor = 1;  wl_boar_factor = 1;
end
fprintf('  Wildlife type: %s (deer_factor=%d, boar_factor=%d)\n', ...
    wildlife_type, wl_deer_factor, wl_boar_factor);

% -------------------------------------------------------------------------
% Rainfall runoff CFU gain (manual switch)
%   use_rainfall_cfu_gain = true  -> add cfu_gain_from_rainfall to irrigation water
%   use_rainfall_cfu_gain = false -> irrigation water = source samples only (no runoff)
%   Default true = manuscript / with-runoff baseline.
% -------------------------------------------------------------------------
use_rainfall_cfu_gain = true;  % manual: true = with runoff, false = without
if ~(islogical(use_rainfall_cfu_gain) || isnumeric(use_rainfall_cfu_gain)) || ~isscalar(use_rainfall_cfu_gain)
    error('use_rainfall_cfu_gain must be a scalar true/false (1/0)');
end
use_rainfall_cfu_gain = logical(use_rainfall_cfu_gain);
if use_rainfall_cfu_gain
    fprintf('  Rainfall runoff CFU gain: ON (irrigation water includes rainfall contribution)\n');
else
    fprintf('  Rainfall runoff CFU gain: OFF (irrigation water = source samples only)\n');
end

% -------------------------------------------------------------------------
% Pond + well blend (manual switch; default OFF so other scenarios unchanged)
%   false -> irrigation CFU = pond/surface (+ optional rainfall) as before
%   true  -> irrigation CFU = 0.5 * pond_cfu + 0.5 * well_cfu
%            pond_cfu = surface sample + optional rainfall gain
%            well_cfu = well_water_cfu_100ml (placeholder 0 until well sampling enabled)
% -------------------------------------------------------------------------
use_pond_well_blend = true;  % manual: true = 50/50 pond/well scenario
well_water_cfu_100ml = 0;     % placeholder; set >0 or wire sample_IrrigationSource2 later
if ~(islogical(use_pond_well_blend) || isnumeric(use_pond_well_blend)) || ~isscalar(use_pond_well_blend)
    error('use_pond_well_blend must be a scalar true/false (1/0)');
end
use_pond_well_blend = logical(use_pond_well_blend);
if ~(isnumeric(well_water_cfu_100ml) && isscalar(well_water_cfu_100ml) && well_water_cfu_100ml >= 0)
    error('well_water_cfu_100ml must be a non-negative scalar');
end
if use_pond_well_blend
    fprintf('  Pond/well blend: ON (0.5*pond[+rainfall] + 0.5*well=%.4g CFU/100mL)\n', ...
        well_water_cfu_100ml);
else
    fprintf('  Pond/well blend: OFF (full pond/surface irrigation source)\n');
end

% -------------------------------------------------------------------------
% Optional soil-only species attribution (Section 3.6)
%   false (default) -> skip extra deer-only / boar-only soil replays (faster)
%   true  -> also run Section 3.6 + Fig 19 + wildlifeSpecies JSON block
% -------------------------------------------------------------------------
run_species_attribution = false;

% Racine et al. prevalence (TODO: rename this var)
prev_min = [78.40, 15.27, 0.464];



% curing decay — Racine et al.
% k = log10 daily decay rate on onion surface (log10/day)
% Normal distribution directly from Racine study
% mean = 0.0983, SD = 0.0111 log10/day
curing_k_dist = makedist('Normal', 'mu', 0.0983, 'sigma', 0.0111);

% curing_mpn0 is NOT sampled here — it comes from model soil CFU
% at the irrigation stop day, extracted per-iteration in Pathway 2
curing_k     = zeros(iterations, 1);
curing_mpn14 = zeros(iterations, 1);
curing_mpn0  = zeros(iterations, 1);  % will be filled in Pathway 2

fprintf('\nPre-computing curing decay rates for %d iterations...\n', iterations);

for i = 1:iterations
    % sample k directly from Normal distribution
    k           = random(curing_k_dist, 1);
    curing_k(i) = k;
    % NOTE: curing_mpn0(i) and curing_mpn14(i) are computed in Pathway 2
    % where soil CFU at irrigation stop day is available
end

fprintf('  k (log10/day): mean=%.4f, std=%.4f\n', mean(curing_k), std(curing_k));
fprintf('  k range P5-P95: [%.4f, %.4f]\n', prctile(curing_k,5), prctile(curing_k,95));
fprintf('  MPN(0) and MPN(14) computed per-iteration in Pathway 2\n');

% monthly soil decay rates (log10CFU/day) - from 10 year from 2016-2025 weather data
% reordered to Jul->Jun
monthly_decay = [-0.07303333,-0.07303333,-0.0793,-0.0793,-0.0793,-0.0793, -0.07953333,-0.07953333,-0.07953333,-0.07953333,-0.07303333, -0.07303333];

% rainfall (mm, Vidalia) - also Jul->Jun rainfall_monthly
rainfall_monthly = [4.408141935, 6.107651613, 2.565386667, 1.365058065, 2.385986667, 2.407354839, 3.441123871,3.491887192, 3.723316129, 2.926093333, 5.046980645, 3.720293333];


fprintf('  Iterations: %d\n', iterations);
fprintf('  Plants: %d\n', plantnum);
fprintf('  Area per plant: %.4f m\xc2\xb2\n', area_per_plant);
%% ========================================================================
%  SECTION 2: WILDLIFE FECAL CONTAMINATION
%% ========================================================================
fprintf('\nGenerating wildlife fecal contamination...\n');

% deer - seasonal fecal weight variation (g/day)
feces_weight_deer = [734.0616, 734.0616,1171.5387, 1171.5387, 1171.5387, 1171.5387, ...
                        440.7372, 440.7372, 440.7372, 440.7372, 425.25, 425.25];

ecoli_feces_dist_deer = makedist('lognormal', 5.95, 0.90);   % E.coli conc in feces
pop_dens_dist_deer = makedist('Triangular', 'a', 0.012, 'b', (0.012+0.06)/2, 'c', 0.06);  % density per ha

CFU_deer = zeros(iterations, 12);
for month = 1:12
    ecoli_feces_deer = random(ecoli_feces_dist_deer, iterations, 1); 
    pop_dens_deer = random(pop_dens_dist_deer, iterations, 1);
    amt_feces_deer = feces_weight_deer(month) * pop_dens_deer;
    CFU_deer(:, month) = amt_feces_deer .* ecoli_feces_deer;
end

% Wild Boar — replaces wild pig and feral pig (consolidated)
% Fecal E. coli: mean = 7.4965 log10 CFU/g, SD = 1.079 log10 CFU/g
% Converted to natural log for makedist:
%   mu (log)   = 7.4965 
%   sigma(log) = 1.079  
wild_boar_seasonal_weight = [1121, 1121, 1121, 1121, 1121, 1121, ...
                              1121, 1121, 1121, 1121, 1121, 1121];

pd_wild_boar = makedist('lognormal', 7.4965, 1.079);
td_wild_boar = makedist('Triangular', 'a', 0.003397, 'b', (0.003397+0.022605)/2, 'c', 0.022605);

CFU_wild_boar = zeros(iterations, 12);
for month = 1:12
    cont_wild_boar       = random(pd_wild_boar, iterations, 1);
    defec_rate_wild_boar = random(td_wild_boar, iterations, 1);
    amt_wild_boar        = wild_boar_seasonal_weight(month) * defec_rate_wild_boar;
    CFU_wild_boar(:, month) = amt_wild_boar .* cont_wild_boar;
end

fprintf('  Deer:      12 months generated\n');
fprintf('  Wild Boar: 12 months generated\n');
fprintf('  Active wildlife type for this run: %s\n', wildlife_type);

%% ========================================================================
%  SECTION 3: SOIL CONTAMINATION BUILD-UP
%% ========================================================================
fprintf('\nBuilding soil contamination matrix (CFU_soil)...\n');

% main 3D array: [iterations x plants x 365]
CFU_soil = zeros(iterations, plantnum, 365);
% Shadow source pools for harvest attribution only (sum equals CFU_soil at all times).
CFU_soil_wl     = zeros(iterations, plantnum, 365);
CFU_soil_irr    = zeros(iterations, plantnum, 365);
CFU_soil_carry  = zeros(iterations, plantnum, 365);

%% PART 0: Carryover from previous year (last 3 months)
fprintf('  Part 0: Previous year carryover...\n');
fprintf('  Part 0: Previous year carryover (from June-end distribution)...\n');

% Self-consistent carryover: if a prior run already fit the model's own
% end-of-June CFU distribution, load and reuse it. Otherwise fall back to
% the fit is (re)computed and saved after each run (end-of-June soil CFU block).
june_end_matfile = 'june_end_cfu_distribution.mat';
if exist(june_end_matfile, 'file')
    prior_fit = load(june_end_matfile, 'mu_fit', 'sigma_fit');
    june_end_dist = makedist('Lognormal', prior_fit.mu_fit, prior_fit.sigma_fit);
    fprintf('  june_end_dist: loaded self-consistent fit from prior run (mu=%.4f, sigma=%.4f)\n', ...
        prior_fit.mu_fit, prior_fit.sigma_fit);
else
    june_end_dist = makedist('Lognormal', -0.7282, 0.3465);
    fprintf('  june_end_dist: no prior run found — using initial literature-based seed (mu=-0.7282, sigma=0.3465)\n');
end

for i = 1:iterations
    carryover = random(june_end_dist, 1);
   
    CFU_soil(i, :, 1) = carryover;
    CFU_soil_carry(i, :, 1) = carryover;
end
%% PART 1: Pre-crop accumulation (before planting)
fprintf('  Part 1: Pre-crop 1 accumulation...\n');

for i = 1:iterations
    for k = 1:(plant1(i) - 1)
        day_idx = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        
        month = get_month_index_jul_start(day_idx);

        if month > 12, month = 12; end
        
        daily_input = (wl_deer_factor * CFU_deer(i, month) + wl_boar_factor * CFU_wild_boar(i, month)) / (plantnum * 30);
        if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            daily_input = 0;
        end

        
        wl_next = CFU_soil_wl(i, :, day_idx) + daily_input;
        irr_next = CFU_soil_irr(i, :, day_idx);
        carry_next = CFU_soil_carry(i, :, day_idx);
        CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, day_idx) + daily_input + 1e-10) + monthly_decay(month));
        [CFU_soil_wl(i, :, next_day_idx), CFU_soil_irr(i, :, next_day_idx), CFU_soil_carry(i, :, next_day_idx)] = ...
            rescale_source_pools(wl_next, irr_next, carry_next, CFU_soil(i, :, next_day_idx));
    end
end
%% PART 2: During crop growth (with year wraparound)
fprintf('  Part 2: During crop 1 (plant-level contamination)...\n');

% pre-generate 20 irrigation water samples per iteration
% FDA Produce Safety Rule: GM 126, STV 410 CFU/100mL
% Targeted scenarios use rejection sampling. The unmanaged scenario does not.
clean_irr_dist = makedist('Lognormal', 2.1, 0.4);     % median ~8
impacted_irr_dist = makedist('Lognormal', 5.1, 0.4);  % median ~164
switch water_quality_scenario
    case 'fda'
        irr_dist = clean_irr_dist;
    case 'non_fda'
        irr_dist = impacted_irr_dist;
    case 'unmanaged'
        irr_dist = [];  % samples are drawn from both distributions below
end
n_irr_samples = 20;
GM_limit = 126;
STV_limit = 410;
max_wq_attempts = 10000;

irr_source_samples = cell(iterations, 1);
irr_GM = zeros(iterations, 1);
irr_STV = zeros(iterations, 1);
irr_meets_fda = false(iterations, 1);
irr_impacted_sample_count = zeros(iterations, 1);
irr_impact_p = zeros(iterations, 1);  % unmanaged only; 0 for fda/non_fda

switch water_quality_scenario
    case 'fda'
        fprintf('    Generating FDA-compliant water quality sets (20 samples each)...\n');
    case 'non_fda'
        fprintf('    Generating FDA-noncompliant water quality sets (20 samples each)...\n');
    case 'unmanaged'
        fprintf('    Generating unmanaged water quality sets (20 samples each; outcome not forced)...\n');
end
for i = 1:iterations
    accepted = false;
    n_attempts = 0;
    p_impact = 0;
    while ~accepted
        n_attempts = n_attempts + 1;
        if n_attempts > max_wq_attempts
            error('water quality sampling: no accepted set after %d attempts (scenario=%s)', ...
                max_wq_attempts, water_quality_scenario);
        end

        if strcmp(water_quality_scenario, 'unmanaged')
            p_impact = betarnd(unmanaged_impact_alpha, unmanaged_impact_beta);
            C_samples = random(clean_irr_dist, n_irr_samples, 1);
            impacted_samples = rand(n_irr_samples, 1) < p_impact;
            n_impacted = sum(impacted_samples);
            if n_impacted > 0
                C_samples(impacted_samples) = random(impacted_irr_dist, n_impacted, 1);
            end
        else
            C_samples = random(irr_dist, n_irr_samples, 1);
            n_impacted = 0;
        end
        log10_C = log10(C_samples);
        
        x_bar = mean(log10_C);
        s = std(log10_C);
        GM = 10^x_bar;
        STV = 10^(x_bar + 1.2816 * s);
        
        meets = (GM <= GM_limit) && (STV <= STV_limit);
        switch water_quality_scenario
            case 'fda'
                accepted = meets;
            case 'non_fda'
                accepted = ~meets;  % GM > 126 or STV > 410
            case 'unmanaged'
                accepted = true;    % classify the natural draw; never force it
        end
    end
    irr_source_samples{i} = C_samples;
    irr_GM(i) = GM;
    irr_STV(i) = STV;
    irr_meets_fda(i) = meets;
    irr_impacted_sample_count(i) = n_impacted;
    if strcmp(water_quality_scenario, 'unmanaged')
        irr_impact_p(i) = p_impact;
    end
    
    if meets
        compliance_label = 'MEETS';
    else
        compliance_label = 'DOES NOT MEET';
    end
    if strcmp(water_quality_scenario, 'unmanaged')
        fprintf('    Iter %d: GM=%.2f, STV=%.2f, %s (p=%.2f, %d/%d impacted; accepted after %d draw(s))\n', ...
            i, GM, STV, compliance_label, p_impact, n_impacted, n_irr_samples, n_attempts);
    else
        fprintf('    Iter %d: GM=%.2f, STV=%.2f, %s (accepted after %d draw(s))\n', ...
            i, GM, STV, compliance_label, n_attempts);
    end
    fprintf('      20 samples (CFU/100mL): ');
    fprintf('%.1f ', C_samples);
    fprintf('\n');
end

fprintf('    GM range: [%.1f, %.1f] (limit: %d)\n', min(irr_GM), max(irr_GM), GM_limit);
fprintf('    STV range: [%.1f, %.1f] (limit: %d)\n', min(irr_STV), max(irr_STV), STV_limit);
fprintf('    Water-quality outcome: %d/%d sets meet the modeled FDA limits (%.1f%%)\n', ...
    sum(irr_meets_fda), iterations, mean(irr_meets_fda) * 100);

irrigation_schedule_crop1 = cell(iterations, 1);
irrigation_concentrations_crop1 = cell(iterations, 1);

for i = 1:iterations
    irr_events = onion_irrig_days(plant1(i), undercut1(i), establishment_days(i), ...
        bulb_start(i), irr_stop_before_undercut, ival);
    irrigation_schedule_crop1{i} = irr_events;
    irr_day_list = [irr_events.doy];
    
    source_cfu_per_event = zeros(length(irr_events), 1);
    
    for k = plant1(i):(har1(i) - 1)
        day_idx = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        
        month = get_month_index_jul_start(day_idx);

        if month > 12, month = 12; end
        
        % distribute wildlife fecal to decided subplots (intrusion days only)
        if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            deer_total_cfu = wl_deer_factor * CFU_deer(i, month);

            deer_per_plant      = distribute_wildlife_to_subplots(deer_total_cfu,                        plantnum, feces_deposit_locations);
            wild_boar_per_plant = distribute_wildlife_to_subplots(wl_boar_factor * CFU_wild_boar(i, month), plantnum, feces_deposit_locations);

            % monthly -> daily (one visit = normal daily amount)
            deer_daily      = deer_per_plant      / 30;
            wild_boar_daily = wild_boar_per_plant / 30;

            wildlife_cfu_per_plant = deer_daily + wild_boar_daily;
            CFU_soil(i, :, day_idx) = CFU_soil(i, :, day_idx) + wildlife_cfu_per_plant;
            CFU_soil_wl(i, :, day_idx) = CFU_soil_wl(i, :, day_idx) + wildlife_cfu_per_plant;
        end
        
        % irrigation water contamination on irrigation days
        if ismember(k, irr_day_list)
            event_idx = find([irr_events.doy] == k, 1);
            stage = irr_events(event_idx).stage;
            
            % source water quality: pull from pre-screened 20 samples (+ optional rainfall)
            rainfall_amount_mm = rainfall_monthly(month);
            if use_rainfall_cfu_gain
                cfu_gain_from_rainfall = calculate_rainfall_cfu_gain(rainfall_amount_mm);
            else
                cfu_gain_from_rainfall = 0;
            end
            sample_idx = mod(event_idx - 1, n_irr_samples) + 1;
            source_baseline_cfu = irr_source_samples{i}(sample_idx);
            pond_cfu = source_baseline_cfu + cfu_gain_from_rainfall;
            if use_pond_well_blend
                source_cfu_100ml = 0.5 * pond_cfu + 0.5 * well_water_cfu_100ml;
            else
                source_cfu_100ml = pond_cfu;
            end
            
            source_cfu_per_event(event_idx) = source_cfu_100ml;  % save for section 4
            
            % how much water hits each plant -> CFU
            irr_depth_in = depth_for_stage(stage, depth) * irrigation_volume_factor;
            water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
            cfu_irrigation_per_plant = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
            
            CFU_soil(i, :, day_idx) = CFU_soil(i, :, day_idx) + cfu_irrigation_per_plant;
            CFU_soil_irr(i, :, day_idx) = CFU_soil_irr(i, :, day_idx) + cfu_irrigation_per_plant;
        end
        
        % daily decay
        if day_idx < 365
            CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, day_idx) + 1e-10) + monthly_decay(month));
            [CFU_soil_wl(i, :, next_day_idx), CFU_soil_irr(i, :, next_day_idx), CFU_soil_carry(i, :, next_day_idx)] = ...
                rescale_source_pools(CFU_soil_wl(i, :, day_idx), CFU_soil_irr(i, :, day_idx), CFU_soil_carry(i, :, day_idx), CFU_soil(i, :, next_day_idx));
        else
            % wrap 365 -> 1
            CFU_soil(i, :, 1) = 10.^(log10(CFU_soil(i, :, 365) + 1e-10) + monthly_decay(month));
            [CFU_soil_wl(i, :, 1), CFU_soil_irr(i, :, 1), CFU_soil_carry(i, :, 1)] = ...
                rescale_source_pools(CFU_soil_wl(i, :, 365), CFU_soil_irr(i, :, 365), CFU_soil_carry(i, :, 365), CFU_soil(i, :, 1));
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
    mean_wl = mean(CFU_soil_wl(i, :, har_day_idx));
    mean_irr = mean(CFU_soil_irr(i, :, har_day_idx));
    mean_carry = mean(CFU_soil_carry(i, :, har_day_idx));
    CFU_soil(i, :, har_day_idx) = mean_cfu;
    CFU_soil_wl(i, :, har_day_idx) = mean_wl;
    CFU_soil_irr(i, :, har_day_idx) = mean_irr;
    CFU_soil_carry(i, :, har_day_idx) = mean_carry;
    
    for k = har1(i):365
        day_idx = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        
        month = get_month_index_jul_start(day_idx);

        if month > 12, month = 12; end
        
        daily_input = (wl_deer_factor * CFU_deer(i, month) + wl_boar_factor * CFU_wild_boar(i, month)) / (plantnum * 30);
        if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            daily_input = 0;
        end
        
        if next_day_idx > day_idx
            wl_next = CFU_soil_wl(i, :, day_idx) + daily_input;
            irr_next = CFU_soil_irr(i, :, day_idx);
            carry_next = CFU_soil_carry(i, :, day_idx);
            CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, day_idx) + daily_input + 1e-10) + monthly_decay(month));
            [CFU_soil_wl(i, :, next_day_idx), CFU_soil_irr(i, :, next_day_idx), CFU_soil_carry(i, :, next_day_idx)] = ...
                rescale_source_pools(wl_next, irr_next, carry_next, CFU_soil(i, :, next_day_idx));
        end
    end
end

pool_reconcile_err = max(abs(CFU_soil(:) - (CFU_soil_wl(:) + CFU_soil_irr(:) + CFU_soil_carry(:))));
fprintf('  Source pool reconciliation (CFU_soil vs tagged pools): max error = %.3e\n', pool_reconcile_err);

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
%  SECTION 3.6: WILDLIFE SPECIES ATTRIBUTION (deer-only / boar-only)
%  Optional (run_species_attribution). Isolated from CFU_soil / CFU_daily.
%  Main baseline already follows wildlife_type; this only adds soil-only
%  deer/boar replays for comparison (Fig 19 + wildlifeSpecies JSON).
%  Irrigation stays ON (full-field attribution under baseline conditions).
%% ========================================================================
if run_species_attribution
fprintf('\n========== WILDLIFE SPECIES ATTRIBUTION ==========\n');
fprintf('  Replaying soil year with deer-only and boar-only (irrigation ON)...\n');
fprintf('  Main CFU_soil / CFU_daily (wildlife_type=%s) are left unchanged.\n', wildlife_type);

species_labels = {'deer_only', 'boar_only'};
attr_deer_factor = [1, 0];
attr_boar_factor = [0, 1];

CFU_daily_deer_only = zeros(iterations, 365);
CFU_daily_boar_only = zeros(iterations, 365);

for s = 1:2
    df = attr_deer_factor(s);
    bf = attr_boar_factor(s);
    fprintf('  Running %s (deer=%.0f, boar=%.0f)...\n', species_labels{s}, df, bf);

    CFU_soil_sp = zeros(iterations, plantnum, 365);

    % --- Carryover: species-masked months 10-12 (do not use both-species june_end_dist)
    for i = 1:iterations
        carryover = (df * (CFU_deer(i,10) + CFU_deer(i,11) + CFU_deer(i,12)) + ...
                     bf * (CFU_wild_boar(i,10) + CFU_wild_boar(i,11) + CFU_wild_boar(i,12))) ...
                    / (3 * plantnum);
        CFU_soil_sp(i, :, 1) = carryover;
    end

    % --- Pre-crop
    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end

            daily_input = (df * CFU_deer(i, month) + bf * CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            CFU_soil_sp(i, :, next_day_idx) = CFU_soil_sp(i, :, day_idx) + daily_input;
            CFU_soil_sp(i, :, next_day_idx) = 10.^(log10(CFU_soil_sp(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    % --- During crop (wildlife masked + irrigation ON, same schedules/concentrations)
    for i = 1:iterations
        irr_events = irrigation_schedule_crop1{i};
        irr_day_list = [irr_events.doy];
        source_cfu_values = irrigation_concentrations_crop1{i};

        for k = plant1(i):(har1(i) - 1)
            day_idx = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end

            if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                deer_per_plant = distribute_wildlife_to_subplots(df * CFU_deer(i, month), plantnum, feces_deposit_locations);
                wild_boar_per_plant = distribute_wildlife_to_subplots(bf * CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                wildlife_cfu_per_plant = (deer_per_plant + wild_boar_per_plant) / 30;
                CFU_soil_sp(i, :, day_idx) = CFU_soil_sp(i, :, day_idx) + wildlife_cfu_per_plant;
            end

            if ismember(k, irr_day_list)
                event_idx = find([irr_events.doy] == k, 1);
                stage = irr_events(event_idx).stage;
                source_cfu_100ml = source_cfu_values(event_idx);
                irr_depth_in = depth_for_stage(stage, depth) * irrigation_volume_factor;
                water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
                cfu_irrigation_per_plant = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
                CFU_soil_sp(i, :, day_idx) = CFU_soil_sp(i, :, day_idx) + cfu_irrigation_per_plant;
            end

            if day_idx < 365
                CFU_soil_sp(i, :, next_day_idx) = 10.^(log10(CFU_soil_sp(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_sp(i, :, 1) = 10.^(log10(CFU_soil_sp(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end
    end

    % --- Post-harvest
    for i = 1:iterations
        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu = mean(CFU_soil_sp(i, :, har_day_idx));
        CFU_soil_sp(i, :, har_day_idx) = mean_cfu;

        for k = har1(i):365
            day_idx = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end

            daily_input = (df * CFU_deer(i, month) + bf * CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            if next_day_idx > day_idx
                CFU_soil_sp(i, :, next_day_idx) = CFU_soil_sp(i, :, day_idx) + daily_input;
                CFU_soil_sp(i, :, next_day_idx) = 10.^(log10(CFU_soil_sp(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
            end
        end
    end

    % --- Collapse to daily field mean
    CFU_daily_sp = zeros(iterations, 365);
    for i = 1:iterations
        for day = 1:365
            CFU_daily_sp(i, day) = mean(CFU_soil_sp(i, :, day));
        end
    end

    if s == 1
        CFU_daily_deer_only = CFU_daily_sp;
    else
        CFU_daily_boar_only = CFU_daily_sp;
    end

    fprintf('    %s mean CFU: %.2e | median: %.2e\n', ...
        species_labels{s}, mean(CFU_daily_sp(:)), median(CFU_daily_sp(:)));
    clear CFU_soil_sp CFU_daily_sp;
end

% Percentile bands for export / figure (main = existing CFU_daily for wildlife_type)
deer_only_pct = zeros(7, 365);
boar_only_pct = zeros(7, 365);
both_species_pct = zeros(7, 365);
for d = 1:365
    vals = CFU_daily_deer_only(:, d);
    deer_only_pct(1,d) = min(vals);   deer_only_pct(2,d) = prctile(vals,5);
    deer_only_pct(3,d) = prctile(vals,25); deer_only_pct(4,d) = prctile(vals,50);
    deer_only_pct(5,d) = prctile(vals,75); deer_only_pct(6,d) = prctile(vals,95);
    deer_only_pct(7,d) = max(vals);

    vals = CFU_daily_boar_only(:, d);
    boar_only_pct(1,d) = min(vals);   boar_only_pct(2,d) = prctile(vals,5);
    boar_only_pct(3,d) = prctile(vals,25); boar_only_pct(4,d) = prctile(vals,50);
    boar_only_pct(5,d) = prctile(vals,75); boar_only_pct(6,d) = prctile(vals,95);
    boar_only_pct(7,d) = max(vals);

    vals = CFU_daily(:, d);
    both_species_pct(1,d) = min(vals);   both_species_pct(2,d) = prctile(vals,5);
    both_species_pct(3,d) = prctile(vals,25); both_species_pct(4,d) = prctile(vals,50);
    both_species_pct(5,d) = prctile(vals,75); both_species_pct(6,d) = prctile(vals,95);
    both_species_pct(7,d) = max(vals);
end

mean_both = mean(CFU_daily(:));
mean_deer = mean(CFU_daily_deer_only(:));
mean_boar = mean(CFU_daily_boar_only(:));
fprintf('\n  Species attribution summary (mean soil CFU, irrigation ON):\n');
fprintf('    Main (wildlife_type=%s): %.4e\n', wildlife_type, mean_both);
fprintf('    Deer only:               %.4e  (%.1f%% of main)\n', mean_deer, mean_deer / mean_both * 100);
fprintf('    Boar only:               %.4e  (%.1f%% of main)\n', mean_boar, mean_boar / mean_both * 100);
fprintf('    (Shares may not sum to 100%% due to nonlinear decay + shared irrigation)\n');

% Figure 19: median daily soil CFU by wildlife species (irrigation ON)
month_boundaries_sp = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months_sp = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
days_sp = 1:365;

figure(19); clf;
plot(days_sp, log10(both_species_pct(4,:) + 1), 'k-', 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Main (%s)', wildlife_type)); hold on;
plot(days_sp, log10(deer_only_pct(4,:) + 1), 'Color', [0.2 0.55 0.25], 'LineStyle', '-', 'LineWidth', 2.0, 'DisplayName', 'Deer only');
plot(days_sp, log10(boar_only_pct(4,:) + 1), 'Color', [0.75 0.35 0.1], 'LineStyle', '-.', 'LineWidth', 2.0, 'DisplayName', 'Boar only');
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Wildlife Species Attribution: Median Soil CFU (Irrigation ON)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10); grid on; xlim([1 365]);
xticks(month_boundaries_sp(1:end-1) + 15); xticklabels(months_sp);
for mb = month_boundaries_sp(2:end-1)
    xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
end
fprintf('  Figure 19 created: wildlife species attribution\n');
fprintf('========== SPECIES ATTRIBUTION COMPLETE ==========\n');
else
fprintf('\n========== WILDLIFE SPECIES ATTRIBUTION SKIPPED ==========\n');
fprintf('  run_species_attribution = false (set true for soil-only deer/boar comparison).\n');
fprintf('  Main run wildlife_type = %s drives full baseline outputs.\n', wildlife_type);
end

%% ========================================================================
%  SECTION 4: ONION SURFACE CONTAMINATION
%% ========================================================================
fprintf('\n========== ONION SURFACE CONTAMINATION ==========\n');
fprintf('Calculating contamination via soil transfer (all sources -> soil -> onion)...\n');

CFU_crop1 = zeros(iterations, plantnum);

% --- soil-to-onion transfer (PERT distribution) ---
pert_min  = 0.0036;
pert_mode = 0.0036;
pert_max  = 0.0585;
lam       = 4;

alpha1 = 1 + lam * (pert_mode - pert_min) / (pert_max - pert_min);
alpha2 = 1 + lam * (pert_max - pert_mode) / (pert_max - pert_min);
beta_dist = makedist('Beta', 'a', alpha1, 'b', alpha2);

fprintf('\nSoil Transfer (irrigation + wildlife + carryover -> soil -> onion)\n');
fprintf('  Transfer model: PERT(min=%.4f, mode=%.6f, max=%.4f)\n', pert_min, pert_mode, pert_max);
fprintf('  Beta shape params: alpha1=%.4f, alpha2=%.4f\n', alpha1, alpha2);


CFU_soil_pathway = zeros(iterations, plantnum);
CFU_soil_pathway_wl = zeros(iterations, plantnum);
CFU_soil_pathway_irr = zeros(iterations, plantnum);
CFU_soil_pathway_carry = zeros(iterations, plantnum);

fprintf('\n--- Processing iterations ---\n');

% extract end-of-June soil CFU for all iterations
june_end_cfu = CFU_daily(:, 365);

% basic stats
fprintf('\nEnd-of-June Soil CFU Distribution:\n');
fprintf('  Mean: %.4e\n', mean(june_end_cfu));
fprintf('  Median: %.4e\n', median(june_end_cfu));
fprintf('  Std: %.4e\n', std(june_end_cfu));
fprintf('  Min: %.4e, Max: %.4e\n', min(june_end_cfu), max(june_end_cfu));

% fit lognormal in NATURAL LOG space — makedist('Lognormal', mu, sigma)
% expects ln(X), not log10(X). Fitting in log10 here would create a
% ~2.3x scale mismatch if fed back into june_end_dist.
ln_vals = log(june_end_cfu + 1e-10);
mu_fit = mean(ln_vals);
sigma_fit = std(ln_vals);
fprintf('  Fitted ln-scale (MATLAB Lognormal params): mu=%.4f, sigma=%.4f\n', mu_fit, sigma_fit);

fprintf('\n  --- COPY THIS LINE INTO SECTION 3 PART 0 FOR THE NEXT RUN ---\n');
fprintf('  june_end_dist = makedist(''Lognormal'', %.4f, %.4f);\n', mu_fit, sigma_fit);
fprintf('  ----------------------------------------------------------------\n');

% save for future use as next-year carryover
save('june_end_cfu_distribution.mat', 'june_end_cfu', 'mu_fit', 'sigma_fit');

% Legacy irrigation-pathway daily matrices (direct route removed; kept for export shape)
CFU_irrigation_daily = zeros(iterations, 365);
CFU_irrigation_plant_daily = zeros(iterations, plantnum, 365);
CFU_irrigation_monthly_avg = zeros(iterations, 12);
fprintf('  Direct irrigation pathway removed; all irrigation enters soil first.\n');

%% SOIL -> ONION SURFACE (bulbing or curing window)
fprintf('\nCalculating soil transfer to onion surface...\n');
fprintf('  Transfer window: %s start, every %d day(s), through harvest\n', ...
    soil_transfer_start, soil_transfer_interval);

for i = 1:iterations
    undercut_day_idx = mod(undercut1(i) - 1, 365) + 1;
    transfer_start_i = soil_transfer_start_day(plant1(i), bulb_start(i), undercut1(i), soil_transfer_start);

    % field-mean accumulators for Figure 15 (diagnostic only; not added to harvest CFU)
    mpn0_sum  = 0;
    mpn14_sum = 0;

    for j = 1:plantnum
        onion_surface_cfu_from_soil = 0;
        onion_wl = 0;
        onion_irr = 0;
        onion_carry = 0;

        % soil → onion transfer (bulbing or undercut start → harvest)
        for k = transfer_start_i:soil_transfer_interval:har1(i)
            day_idx = mod(k - 1, 365) + 1;

            if k < har1(i)
                month = get_month_index_jul_start(day_idx);
                if month > 12, month = 12; end

                transfer_coefficient = pert_min + (pert_max - pert_min) * random(beta_dist, 1);

                CFU_transfer = transfer_coefficient * CFU_soil(i, j, day_idx);
                CFU_transfer_wl = transfer_coefficient * CFU_soil_wl(i, j, day_idx);
                CFU_transfer_irr = transfer_coefficient * CFU_soil_irr(i, j, day_idx);
                CFU_transfer_carry = transfer_coefficient * CFU_soil_carry(i, j, day_idx);
                onion_surface_cfu_from_soil = onion_surface_cfu_from_soil + CFU_transfer;
                onion_wl = onion_wl + CFU_transfer_wl;
                onion_irr = onion_irr + CFU_transfer_irr;
                onion_carry = onion_carry + CFU_transfer_carry;

                decayed_total = 10^(log10(onion_surface_cfu_from_soil + 1e-10) + monthly_decay(month));
                [onion_wl, onion_irr, onion_carry] = rescale_source_pools(onion_wl, onion_irr, onion_carry, decayed_total);
                onion_surface_cfu_from_soil = decayed_total;
            end
        end

        % model soil CFU at undercutting → MPN(0), then Racine k decay over curing_days
        soil_cfu_at_undercut = CFU_soil(i, j, undercut_day_idx);
        if soil_cfu_at_undercut > 0
            mpn_day0_model = log10(soil_cfu_at_undercut);
        else
            mpn_day0_model = 0;
        end
        predicted_mpn = max(0, mpn_day0_model - curing_k(i) * curing_days);

        mpn0_sum  = mpn0_sum  + mpn_day0_model;
        mpn14_sum = mpn14_sum + predicted_mpn;

        CFU_soil_pathway(i, j) = onion_surface_cfu_from_soil;
        CFU_soil_pathway_wl(i, j) = onion_wl;
        CFU_soil_pathway_irr(i, j) = onion_irr;
        CFU_soil_pathway_carry(i, j) = onion_carry;
    end

    % store field-mean values for Figure 15 after j loop closes
    curing_mpn0(i)  = mpn0_sum  / plantnum;
    curing_mpn14(i) = mpn14_sum / plantnum;

    if mod(i, 50) == 0
        fprintf('  Pathway 2: Iteration %d/%d complete\n', i, iterations);
    end
end

fprintf('  Curing MPN(0) from model soil (field mean): mean=%.4f, std=%.4f\n', ...
        mean(curing_mpn0), std(curing_mpn0));
fprintf('  Harvest MPN log10 (after %d curing days, field mean): mean=%.4f, std=%.4f\n', ...
        curing_days, mean(curing_mpn14), std(curing_mpn14));
fprintf('  Fraction of iterations with field-mean MPN(14)=0: %.1f%%\n', ...
        sum(curing_mpn14 == 0) / iterations * 100);

% Figure 15 — after Pathway 2, curing_mpn0 and curing_mpn14 are populated
figure(15); clf;
n_examples   = min(10, iterations);
scatter_days = [0, curing_days];          % day 0 (undercut) and harvest
day_range    = linspace(0, curing_days, 100);
hold on;
for idx = 1:n_examples
    mpn_points  = [curing_mpn0(idx), curing_mpn14(idx)];
    decay_curve = max(0, curing_mpn0(idx) - curing_k(idx) * day_range);
    plot(scatter_days, mpn_points, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
    plot(day_range, decay_curve, '-', 'LineWidth', 1.2);
end
xline(curing_days, 'k--', 'LineWidth', 2.0, ...
      'Label', sprintf('Harvest Day %d', curing_days));
hold off;
xlabel('Days of Field Curing', 'FontSize', 12);
ylabel('log_{10}(MPN per onion bulb)', 'FontSize', 12);
title('E. coli Survival — Diagnostic Curing Decay From Model Soil CFU at Undercutting', ...
      'FontSize', 13, 'FontWeight', 'bold');
subtitle(sprintf('k ~ Normal(%.4f, %.4f) log_{10}/day | Not added to harvest CFU', ...
         0.0983, 0.0111), 'FontSize', 10);
grid on;
xlim([0 curing_days + 1]);
fprintf('  Figure 15 created: Curing decay from model soil CFU\n');

%% ========================================================================
%  SECTION 4.5: DAILY SOIL PATHWAY TRACKING
%% ========================================================================

CFU_soil_pathway_daily_v2 = zeros(iterations, 365);
CFU_soil_pathway_plant_daily = zeros(iterations, plantnum, 365);

for i = 1:iterations
    undercut_day_idx = mod(undercut1(i) - 1, 365) + 1;
    transfer_start_i = soil_transfer_start_day(plant1(i), bulb_start(i), undercut1(i), soil_transfer_start);

    for j = 1:plantnum
        cumulative_cfu = 0;

        transfer_days = transfer_start_i:soil_transfer_interval:har1(i);

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
    fprintf('  Total daily sum: %.4e\n', daily_sum);
    fprintf('  Harvest day: %d\n\n', har1(i));
end

fprintf('Note: Daily tracking spreads contamination across the curing period,\n');
fprintf('while original CFU_soil_pathway shows the final accumulated value.\n');
fprintf('========================================\n');



%% ========================================================================
%  HARVEST ONION SURFACE CFU
%% ========================================================================
fprintf('\n--- Final harvest onion-surface CFU (soil transfer route only) ---\n');

CFU_crop1 = CFU_soil_pathway;

fprintf('\nCONTAMINATION SUMMARY:\n');
fprintf('  Soil transfer route (all sources via soil):\n');
fprintf('    Mean CFU: %.2e\n', mean(CFU_soil_pathway(:)));
fprintf('    Max CFU: %.2e\n', max(CFU_soil_pathway(:)));
fprintf('    Non-zero samples: %d (%.1f%%)\n', ...
        sum(CFU_soil_pathway(:) > 0), ...
        sum(CFU_soil_pathway(:) > 0) / numel(CFU_soil_pathway) * 100);

fprintf('\n  Harvest total:\n');
fprintf('    Mean CFU: %.2e\n', mean(CFU_crop1(:)));
fprintf('    Median CFU: %.2e\n', median(CFU_crop1(:)));
fprintf('    Max CFU: %.2e\n', max(CFU_crop1(:)));
fprintf('    Std Dev: %.2e\n', std(CFU_crop1(:)));

irrigation_contribution = 0;
soil_contribution       = 100;

% Source attribution at harvest onion surface (shadow pools).
CFU_harvest_wl    = CFU_soil_pathway_wl;
CFU_harvest_irr   = CFU_soil_pathway_irr;
CFU_harvest_carry = CFU_soil_pathway_carry;
pathway_tag_err = max(abs(CFU_soil_pathway(:) - (CFU_soil_pathway_wl(:) + CFU_soil_pathway_irr(:) + CFU_soil_pathway_carry(:))));
fprintf('  Pathway source-tag reconciliation: max error = %.3e\n', pathway_tag_err);

wildlife_source_pct   = mean(CFU_harvest_wl(:))    / mean(CFU_crop1(:)) * 100;
irrigation_source_pct = mean(CFU_harvest_irr(:))  / mean(CFU_crop1(:)) * 100;
carryover_source_pct  = mean(CFU_harvest_carry(:)) / mean(CFU_crop1(:)) * 100;


fprintf('\n  Source Contributions (harvest onion surface):\n');
fprintf('    Wildlife: %.1f%% of total\n', wildlife_source_pct);
fprintf('    Irrigation (via soil): %.1f%% of total\n', irrigation_source_pct);
fprintf('    Prior-season carryover: %.1f%% of total\n', carryover_source_pct);


%% ========================================================================
%  SECTION 5: ORGANIZE BY HARVEST MONTH
%% ========================================================================
fprintf('\nOrganizing outputs by harvest month...\n');

CFU_crop1_monthly = cell(12, 1);
CFU_irrigation_monthly = cell(12, 1);  % irrigation-tagged harvest CFU (soil route)
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
    CFU_irrigation_monthly{month1} = [CFU_irrigation_monthly{month1}; CFU_soil_pathway_irr(i, :)];
    CFU_soil_monthly{month1} = [CFU_soil_monthly{month1}; CFU_soil_pathway(i, :)];
end

months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

Max_crop1 = zeros(12, 1);
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

fprintf('\nSOURCE CONTRIBUTIONS (harvest onion surface):\n');
fprintf('  Wildlife:\n');
fprintf('    Mean: %.2e CFU (%.1f%% of total)\n', ...
        mean(CFU_harvest_wl(:)), ...
        mean(CFU_harvest_wl(:)) / mean(CFU_crop1(:)) * 100);

fprintf('  Irrigation (via soil):\n');
fprintf('    Mean: %.2e CFU (%.1f%% of total)\n', ...
        mean(CFU_harvest_irr(:)), ...
        mean(CFU_harvest_irr(:)) / mean(CFU_crop1(:)) * 100);

fprintf('  Prior-season carryover:\n');
fprintf('    Mean: %.2e CFU (%.1f%% of total)\n', ...
        mean(CFU_harvest_carry(:)), ...
        mean(CFU_harvest_carry(:)) / mean(CFU_crop1(:)) * 100);

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

%% Figure 1: harvest distribution
figure(1); clf;

subplot(1,2,1);
data2 = CFU_soil_pathway(CFU_soil_pathway > 0);
if ~isempty(data2)
    histogram(log10(data2), 30, 'FaceColor', 'r', 'EdgeColor', 'w');
end
xlabel('log_{10}(CFU)');
ylabel('Frequency');
title('Soil Transfer Route');
grid on;

subplot(1,2,2);
data3 = CFU_crop1(CFU_crop1 > 0);
if ~isempty(data3)
    histogram(log10(data3), 30, 'FaceColor', 'g', 'EdgeColor', 'w');
end
xlabel('log_{10}(CFU)');
ylabel('Frequency');
title('Harvest Onion Surface');
grid on;

sgtitle('Contamination Distribution at Harvest (Log Scale)');

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

%% Figure 3: source contribution by month
figure(3); clf;
bar([Mean_irrigation', Mean_soil' - Mean_irrigation'], 'stacked');
set(gca, 'XTickLabel', months);
xlabel('Harvest Month');
ylabel('Mean CFU per subplot');
legend('Irrigation (via soil)', 'Wildlife + carryover', 'Location', 'best');
title('Harvest Onion-Surface CFU by Source Tag');
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

%% Figure 5: onion-surface soil-transfer time-series
fprintf('\nGenerating onion-surface soil-transfer time-series visualization...\n');

figure(5); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

subplot(2,1,1);
daily_mean = mean(CFU_soil_pathway_daily_v2, 1);
daily_std = std(CFU_soil_pathway_daily_v2, 0, 1);

semilogy(1:365, max(daily_mean, 1e-10), 'r-', 'LineWidth', 2);
hold on;

upper = max(daily_mean + daily_std, 1e-10);
lower = max(daily_mean - daily_std, 1e-10);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean CFU per subplot ', 'FontSize', 11);
title('Onion Surface CFU via Soil Transfer', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
xlim([1 365]);
ylim([1e-5 1e5]);

xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

subplot(2,1,2);
monthly_mean = mean(CFU_soil_pathway_monthly_avg, 1);
bar(monthly_mean);
set(gca, 'XTickLabel', months);
xlabel('Month', 'FontSize', 11);
ylabel('Mean CFU per subplot', 'FontSize', 11);
title('Monthly Average Onion-Surface CFU (Soil Route)', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
set(gca, 'YScale', 'log');
ylim([1e-5 1e5]);

fprintf('Onion-surface soil-transfer visualization complete!\n');

%% Figure 6: onion-surface soil transfer over time
figure(6); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

daily_soil = mean(CFU_soil_pathway_daily_v2, 1);

subplot(2,1,1);
semilogy(1:365, max(daily_soil, 1e-10), 'r-', 'LineWidth', 2, 'DisplayName', 'Soil transfer to onion');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean CFU per subplot', 'FontSize', 11);
title('Daily Onion-Surface CFU (Soil Transfer Route)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best');
grid on;
xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

subplot(2,1,2);
cumulative_soil = cumsum(daily_soil);
semilogy(1:365, max(cumulative_soil, 1e-10), 'r-', 'LineWidth', 2, 'DisplayName', 'Soil transfer');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Cumulative mean CFU per subplot ', 'FontSize', 11);
title('Cumulative Onion-Surface CFU (Soil Route)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best');
grid on;
xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15);
xticklabels(months);

fprintf('Onion-surface soil-transfer visualization complete!\n');


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



%% Figure 8: combined 2-panel overview (soil reservoir + onion surface)
figure(8); clf;

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

daily_soil_pathway_mean = mean(CFU_soil_pathway_daily_v2, 1);
daily_soil_pathway_std = std(CFU_soil_pathway_daily_v2, 0, 1);
daily_cfu_mean = mean(CFU_daily, 1);
daily_cfu_std = std(CFU_daily, 0, 1);

subplot(2, 1, 1);
semilogy(1:365, max(daily_cfu_mean, 1e-10), 'g-', 'LineWidth', 2);
hold on;
upper = max(daily_cfu_mean + daily_cfu_std, 1e-10);
lower = max(daily_cfu_mean - daily_cfu_std, 1e-6);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean CFU per subplot', 'FontSize', 11);
title('Soil CFU (wildlife + irrigation + carryover)', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([1 365]); ylim([1e-6 1e5]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(2, 1, 2);
semilogy(1:365, max(daily_soil_pathway_mean, 1e-10), 'r-', 'LineWidth', 2);
hold on;
upper = max(daily_soil_pathway_mean + daily_soil_pathway_std, 1e-10);
lower = max(daily_soil_pathway_mean - daily_soil_pathway_std, 1e-10);
fill([1:365, 365:-1:1], [upper, fliplr(lower)], ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Day of Year', 'FontSize', 11);
ylabel('Mean CFU per subplot', 'FontSize', 11);
title('Onion Surface CFU via Soil Transfer', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([1 365]); ylim([1e-5 1e5]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

sgtitle('Soil Reservoir and Onion-Surface CFU (Log Scale)', ...
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

% onion-surface percentiles (soil transfer route; direct irrigation pathway removed)
irrig_pct = zeros(7, 365);
for d = 1:365
    vals = CFU_soil_pathway_daily_v2(:, d);
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

% Figure 10: onion-surface daily percentiles (soil transfer route)
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
title('Daily Onion-Surface CFU via Soil Transfer', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1)
    xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
end
fprintf('  Figure 10 created: Onion-surface soil-transfer daily percentiles\n');

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

cure_window_days = 28;  % viz window (last N days before harvest; not manuscript curing)

% d=1 is 27 days before harvest, d=28 is harvest day
curing_soil     = zeros(iterations, cure_window_days);
curing_irrig    = zeros(iterations, cure_window_days);
curing_soilpath = zeros(iterations, cure_window_days);

for i = 1:iterations
    for d = 1:cure_window_days
        actual_day = har1(i) - (cure_window_days - d);
        day_idx = mod(actual_day - 1, 365) + 1;
        
        curing_soil(i, d)     = CFU_daily(i, day_idx);
        curing_irrig(i, d)    = CFU_irrigation_daily(i, day_idx);
        curing_soilpath(i, d) = CFU_soil_pathway_daily_v2(i, day_idx);
    end
end

fprintf('  Extracted 28-day curing window for %d iterations.\n', iterations);
fprintf('  Harvest days range: %d to %d\n', min(har1), max(har1));

% percentiles across iterations for each curing day
cure_soil_pct     = zeros(7, cure_window_days);
cure_irrig_pct    = zeros(7, cure_window_days);
cure_soilpath_pct = zeros(7, cure_window_days);

for d = 1:cure_window_days
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

xline(-(curing_days + irr_stop_before_undercut), 'k--', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Last irrig (~Day -%d)', curing_days + irr_stop_before_undercut));
xline(-curing_days, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Undercut (~Day -%d)', curing_days));

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
% onion surface CFU from bulbing start through harvest (soil transfer route only)
fprintf('\n========== ONION SURFACE E. COLI: BULBING TO HARVEST ==========\n');

bulbing_day = plant1 + bulb_start;
days_bulb_to_harvest = har1 - bulbing_day;

max_duration = max(days_bulb_to_harvest);

fprintf('  Bulbing start range: Day %d to %d\n', min(bulbing_day), max(bulbing_day));
fprintf('  Harvest range: Day %d to %d\n', min(har1), max(har1));
fprintf('  Bulb-to-harvest duration: %d to %d days (max window = %d)\n', ...
    min(days_bulb_to_harvest), max(days_bulb_to_harvest), max_duration);

onion_surface_daily = NaN(iterations, max_duration);
onion_soilpath_component = NaN(iterations, max_duration);

fprintf('  Building onion surface matrix [%d x %d]...\n', iterations, max_duration);

for i = 1:iterations
    n_days = days_bulb_to_harvest(i);

    for d = 1:n_days
        actual_day = bulbing_day(i) + d - 1;
        day_idx = mod(actual_day - 1, 365) + 1;

        soilpath_per_plant = squeeze(CFU_soil_pathway_plant_daily(i, :, day_idx));
        mean_soilpath = mean(soilpath_per_plant);

        onion_soilpath_component(i, d) = mean_soilpath;
        onion_surface_daily(i, d) = mean_soilpath;
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

xline(max_duration, 'k--', 'LineWidth', 1.8, 'DisplayName', 'Harvest');

hold off;

xlabel('Days Since Bulbing Start', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Onion Surface E. coli via Soil Transfer: Bulbing to Harvest', ...
      'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
grid on;
xlim([1 max_duration]);
fprintf('  Figure 17 created: Onion surface E. coli bulbing to harvest\n');

% Figure 18: median onion surface (soil route)
figure(18); clf;

median_soilpath_comp = zeros(1, max_duration);
median_total = zeros(1, max_duration);

for d = 1:max_duration
    v2 = onion_soilpath_component(:, d);
    v2 = v2(~isnan(v2));
    if ~isempty(v2), median_soilpath_comp(d) = median(v2); end

    v3 = onion_surface_daily(:, d);
    v3 = v3(~isnan(v3));
    if ~isempty(v3), median_total(d) = median(v3); end
end

plot(x_days, log10(median_total + 1), 'k-', 'LineWidth', 2.5, ...
    'DisplayName', 'Onion Surface (soil route)');
hold off;

xlabel('Days Since Bulbing Start', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Median Onion-Surface CFU via Soil Transfer', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
xlim([1 max_duration]);
fprintf('  Figure 18 created: Median onion-surface soil transfer\n');

fprintf('\n--- Onion Surface CFU Summary (Median across iterations) ---\n');
fprintf('  %-30s  %12s  %12s\n', '', 'Bulbing Start', 'Harvest');
fprintf('  %s\n', repmat('-', 1, 56));

fprintf('  %-30s  %12.4f  %12.4f\n', 'Total Surface (median)', ...
    surface_pct(4,1), surface_pct(4,max_duration));
fprintf('  %-30s  %12.4f  %12.4f\n', 'Soil Transfer Component', ...
    median_soilpath_comp(1), median_soilpath_comp(max_duration));


%% ========================================================================
%  SECTION 11: THRESHOLD EXCEEDANCE DURING CURING
%% ========================================================================
% count plants above thresholds on the onion surface for each of the 28 curing days
fprintf('\n========== PLANTS EXCEEDING THRESHOLDS - 28-DAY CURING ==========\n');

%thresholds = [10, 20, 50, 100];
thresholds = [1, 5, 10, 20];
n_thresh = length(thresholds);
cure_window_days = 28;  % viz window (last N days before harvest; not manuscript curing)

plants_exceed = zeros(iterations, cure_window_days, n_thresh);

fprintf('  Computing plant counts for %d iterations x %d days x %d thresholds...\n', ...
    iterations, cure_window_days, n_thresh);

for i = 1:iterations
    for d = 1:cure_window_days
        actual_day = har1(i) - (cure_window_days - d);
        day_idx = mod(actual_day - 1, 365) + 1;
        
        % onion surface CFU (soil transfer route only)
        onion_surface_cfu = squeeze(CFU_soil_pathway_plant_daily(i, :, day_idx));
        
        for t = 1:n_thresh
            plants_exceed(i, d, t) = sum(onion_surface_cfu > thresholds(t));
        end
    end
    
    if mod(i, 50) == 0
        fprintf('    Iteration %d/%d complete\n', i, iterations);
    end
end

mean_plants_exceed = zeros(cure_window_days, n_thresh);
for d = 1:cure_window_days
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

xline(-(curing_days + irr_stop_before_undercut), 'k--', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Last irrig (~Day -%d)', curing_days + irr_stop_before_undercut));
xline(-curing_days, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Undercut (~Day -%d)', curing_days));
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
    day_label = -(cure_window_days - rd);
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
    day_label = -(cure_window_days - rd);
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
dashboard_data_dir = fullfile(pwd, 'dashboard', 'public', 'data');
fprintf('  Export directory: %s\n', export_dir);
fprintf('  Dashboard data directory: %s\n', dashboard_data_dir);

if ~exist(export_dir, 'dir')
    [status, msg] = mkdir(export_dir);
    if status == 0
        error('Could not create export directory: %s\nReason: %s', export_dir, msg);
    end
    fprintf('  Created export/ folder.\n');
else
    fprintf('  export/ folder already exists.\n');
end

if ~exist(dashboard_data_dir, 'dir')
    [status, msg] = mkdir(dashboard_data_dir);
    if status == 0
        error('Could not create dashboard data directory: %s\nReason: %s', dashboard_data_dir, msg);
    end
    fprintf('  Created dashboard/public/data/ folder.\n');
end

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

collapse_row_to_monthly = @(daily_row) arrayfun(@(m) ...
    mean(daily_row((month_boundaries(m)+1):month_boundaries(m+1))), 1:12);

fprintf('  Writing baseline JSON (wildlife_type=%s)...\n', wildlife_type);

baseline_data = struct();
baseline_data.parameter = 'baseline';
baseline_data.wildlifeType = wildlife_type;

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
baseline_data.monthly.irrigationPathway = mean(CFU_soil_pathway_monthly_avg, 1);
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
baseline_data.pathwayContribution.note = 'Legacy route split; all contamination now uses soil-transfer route only.';

% --- source contribution (wildlife vs irrigation vs carryover at harvest) ---
baseline_data.sourceContribution.wildlifePct   = wildlife_source_pct;
baseline_data.sourceContribution.irrigationPct = irrigation_source_pct;
baseline_data.sourceContribution.carryoverPct  = carryover_source_pct;
baseline_data.sourceContribution.note = ['Harvest onion-surface CFU by contamination source. ', ...
    'All sources enter soil first, then transfer to onion (bulbing-start daily). ', ...
    'IrrigationPct is irrigation-tagged soil CFU at harvest.'];

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

% --- Fig 15: curing decay curves (up to 10 iterations) ---
n_cure_export = min(10, iterations);
baseline_data.curingDecay.k           = curing_k(1:n_cure_export)';
baseline_data.curingDecay.mpn0        = curing_mpn0(1:n_cure_export)';
baseline_data.curingDecay.mpn14       = curing_mpn14(1:n_cure_export)';
baseline_data.curingDecay.irrStopDay  = curing_days;  % curing length (undercut→harvest); legacy field name
baseline_data.curingDecay.curingDays = curing_days;
baseline_data.curingDecay.irrStopBeforeUndercutDays = irr_stop_before_undercut;
baseline_data.curingDecay.kMean       = mean(curing_k);
baseline_data.curingDecay.kStd        = std(curing_k);
baseline_data.curingDecay.mpn14Mean   = mean(curing_mpn14);
baseline_data.curingDecay.mpn14Std    = std(curing_mpn14);
baseline_data.curingDecay.fractionZero = sum(curing_mpn14 == 0) / iterations;

% --- Fig 16/20: curing window aligned to curing_days (slice from 28-day viz buffer) ---
cure_export_days = max(curing_days, 1);
cure_export_start = cure_window_days - cure_export_days + 1;
cure_export_cols = cure_export_start:cure_window_days;
cure_days_relative = (-(cure_export_days - 1)):0;

baseline_data.curingPeriod.soilCFU.min            = cure_soil_pct(1, cure_export_cols);
baseline_data.curingPeriod.soilCFU.p05            = cure_soil_pct(2, cure_export_cols);
baseline_data.curingPeriod.soilCFU.p25            = cure_soil_pct(3, cure_export_cols);
baseline_data.curingPeriod.soilCFU.p50            = cure_soil_pct(4, cure_export_cols);
baseline_data.curingPeriod.soilCFU.p75            = cure_soil_pct(5, cure_export_cols);
baseline_data.curingPeriod.soilCFU.p95            = cure_soil_pct(6, cure_export_cols);
baseline_data.curingPeriod.soilCFU.max            = cure_soil_pct(7, cure_export_cols);
baseline_data.curingPeriod.daysRelativeToHarvest  = cure_days_relative;

baseline_data.curingPeriod.thresholdExceedance.mean       = mean_plants_exceed(cure_export_cols, :);
baseline_data.curingPeriod.thresholdExceedance.meanPct    = mean_plants_exceed(cure_export_cols, :) / plantnum * 100;
baseline_data.curingPeriod.thresholdExceedance.thresholds = thresholds;
baseline_data.curingPeriod.thresholdExceedance.daysRelativeToHarvest = cure_days_relative;

% --- Fig 17: onion surface percentile fan from bulbing to harvest ---
baseline_data.onionSurface.min           = surface_pct(1,:);
baseline_data.onionSurface.p05           = surface_pct(2,:);
baseline_data.onionSurface.p25           = surface_pct(3,:);
baseline_data.onionSurface.p50           = surface_pct(4,:);
baseline_data.onionSurface.p75           = surface_pct(5,:);
baseline_data.onionSurface.p95           = surface_pct(6,:);
baseline_data.onionSurface.max           = surface_pct(7,:);
baseline_data.onionSurface.maxDuration   = max_duration;
median_irr_stop = max_duration;

% --- Fig 18: median onion surface (soil route) ---
baseline_data.onionSurface.medianTotal     = median_total;
baseline_data.onionSurface.medianIrrigComp = zeros(size(median_total));
baseline_data.onionSurface.medianSoilComp  = median_soilpath_comp;

% --- Fig 1: contamination distribution histograms ---
soil_pos   = CFU_soil_pathway(CFU_soil_pathway > 0);
comb_pos   = CFU_crop1(CFU_crop1 > 0);

baseline_data.histograms.irrigationLog10.counts = zeros(1,30);
baseline_data.histograms.irrigationLog10.edges  = linspace(-10, 0, 31);

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

% --- Optional soil-only species attribution (only if Section 3.6 ran) ---
if run_species_attribution
    baseline_data.wildlifeSpecies.irrigationIncluded = true;
    baseline_data.wildlifeSpecies.note = sprintf([ ...
        'Optional soil-only deer/boar replays; main baseline wildlifeType=%s. ', ...
        'Set run_species_attribution=true to populate this block.'], wildlife_type);
    baseline_data.wildlifeSpecies.both.daily.min = both_species_pct(1,:);
    baseline_data.wildlifeSpecies.both.daily.p05 = both_species_pct(2,:);
    baseline_data.wildlifeSpecies.both.daily.p25 = both_species_pct(3,:);
    baseline_data.wildlifeSpecies.both.daily.p50 = both_species_pct(4,:);
    baseline_data.wildlifeSpecies.both.daily.p75 = both_species_pct(5,:);
    baseline_data.wildlifeSpecies.both.daily.p95 = both_species_pct(6,:);
    baseline_data.wildlifeSpecies.both.daily.max = both_species_pct(7,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.min = deer_only_pct(1,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.p05 = deer_only_pct(2,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.p25 = deer_only_pct(3,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.p50 = deer_only_pct(4,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.p75 = deer_only_pct(5,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.p95 = deer_only_pct(6,:);
    baseline_data.wildlifeSpecies.deerOnly.daily.max = deer_only_pct(7,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.min = boar_only_pct(1,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.p05 = boar_only_pct(2,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.p25 = boar_only_pct(3,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.p50 = boar_only_pct(4,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.p75 = boar_only_pct(5,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.p95 = boar_only_pct(6,:);
    baseline_data.wildlifeSpecies.boarOnly.daily.max = boar_only_pct(7,:);
    baseline_data.wildlifeSpecies.summary.meanBoth = mean_both;
    baseline_data.wildlifeSpecies.summary.meanDeerOnly = mean_deer;
    baseline_data.wildlifeSpecies.summary.meanBoarOnly = mean_boar;
    baseline_data.wildlifeSpecies.summary.deerPctOfBoth = mean_deer / mean_both * 100;
    baseline_data.wildlifeSpecies.summary.boarPctOfBoth = mean_boar / mean_both * 100;
end
baseline_data.harvestTiming.irrStopBeforeUndercutDays = irr_stop_before_undercut;
baseline_data.harvestTiming.curingDays = curing_days;
baseline_data.harvestTiming.establishmentDaysRange = [14, 28];
baseline_data.harvestTiming.vegetativeDaysRange = [28, 35];
baseline_data.harvestTiming.bulbDevelopmentDaysRange = [42, 56];
baseline_data.harvestTiming.maturationDaysRange = [7, 14];
baseline_data.harvestTiming.bulbingDaysRange = [49, 70];
baseline_data.harvestTiming.growthDaysRange = [91, 133];
baseline_data.harvestTiming.note = ['Irrigation stops irrStopBeforeUndercutDays before undercutting; ', ...
    'curingDays is undercutting to harvest. Stage durations are independent discrete-uniform draws.'];
baseline_data.irrigationSchedule.establishDepthIn = depth.Establish;
baseline_data.irrigationSchedule.establishIntervalDays = ival.Establish;
baseline_data.irrigationSchedule.vegDepthIn = depth.Veg;
baseline_data.irrigationSchedule.vegIntervalDays = ival.Veg;
baseline_data.irrigationSchedule.bulbDepthPertMinIn = depth.BulbMin;
baseline_data.irrigationSchedule.bulbDepthPertModeIn = depth.BulbMode;
baseline_data.irrigationSchedule.bulbDepthPertMaxIn = depth.BulbMax;
baseline_data.irrigationSchedule.bulbIntervalDays = ival.Bulb;
baseline_data.irrigationSchedule.volumeFactor = irrigation_volume_factor;
baseline_data.irrigationSchedule.note = ['Stage irrigation depth (inches) and interval (days). ', ...
    'Establish/Veg are fixed depth; Bulb depth sampled per event from PERT(min, mode, max). ', ...
    'volumeFactor scales all stage depths (1=baseline, 0.75=25% reduction, 0.50=50% reduction, 0.25=75% reduction).'];
baseline_data.soilTransfer.start = soil_transfer_start;
baseline_data.soilTransfer.intervalDays = soil_transfer_interval;
baseline_data.soilTransfer.bulbStartDap = round(median(bulb_start));
baseline_data.soilTransfer.bulbStartDapRange = [42, 63];
baseline_data.soilTransfer.note = ['Soil-to-onion PERT transfer for harvest CFU. ', ...
    'All contamination uses soil route only (no direct irrigation pathway). ', ...
    'start=bulbing uses each iteration''s establishment+vegetative duration; intervalDays 1=daily, 7=weekly.'];
baseline_data.waterQuality.scenario = water_quality_scenario;
if strcmp(water_quality_scenario, 'unmanaged')
    baseline_data.waterQuality.meetsFda = NaN;  % JSON null: outcome varies by iteration
else
    baseline_data.waterQuality.meetsFda = water_meets_fda;
end
baseline_data.waterQuality.gmLimit = GM_limit;
baseline_data.waterQuality.stvLimit = STV_limit;
baseline_data.waterQuality.gmMean = mean(irr_GM);
baseline_data.waterQuality.gmMin = min(irr_GM);
baseline_data.waterQuality.gmMax = max(irr_GM);
baseline_data.waterQuality.stvMean = mean(irr_STV);
baseline_data.waterQuality.stvMin = min(irr_STV);
baseline_data.waterQuality.stvMax = max(irr_STV);
baseline_data.waterQuality.iterationMeetsFda = irr_meets_fda;
baseline_data.waterQuality.meetingCount = sum(irr_meets_fda);
baseline_data.waterQuality.meetingPercent = mean(irr_meets_fda) * 100;
baseline_data.waterQuality.unmanagedImpactAlpha = unmanaged_impact_alpha;
baseline_data.waterQuality.unmanagedImpactBeta  = unmanaged_impact_beta;
baseline_data.waterQuality.unmanagedImpactProbability = unmanaged_impact_mean;  % prior mean
baseline_data.waterQuality.unmanagedImpactProbabilityByIter = irr_impact_p;
baseline_data.waterQuality.impactedSampleCount = irr_impacted_sample_count;
baseline_data.waterQuality.note = ['Surface irrigation water: 20-sample GM/STV. ', ...
    'fda uses Lognormal(2.1,0.4) and accepts only sets with GM<=126 and STV<=410; ', ...
    'non_fda uses Lognormal(5.1,0.4) and accepts only sets with GM>126 or STV>410; ', ...
    'unmanaged draws p~Beta(alpha,beta) each iteration, impacts each sample with ', ...
    'probability p, and accepts the set without screening, so compliance is an ', ...
    'outcome rather than a target.'];
baseline_data.wildlifeIntrusion.useSchedule = use_intrusion_schedule;
baseline_data.wildlifeIntrusion.intervalDays = intrusion_interval;
baseline_data.wildlifeIntrusion.fecesDepositLocations = feces_deposit_locations;
baseline_data.wildlifeIntrusion.note = sprintf(['When useSchedule is true, each visit drops normal daily feces (monthly/30); ', ...
    'fewer visits => less total feces. Feces deposit locations = %d (total CFU conserved per pooping event).'], ...
    feces_deposit_locations);
baseline_data.rainfallRunoff.useRainfallCfuGain = use_rainfall_cfu_gain;
baseline_data.rainfallRunoff.note = ['When useRainfallCfuGain is true, irrigation source CFU includes ', ...
    'calculate_rainfall_cfu_gain(monthly rainfall mm). When false, irrigation uses screened source samples only (no runoff).'];
baseline_data.pondWellBlend.usePondWellBlend = use_pond_well_blend;
baseline_data.pondWellBlend.wellWaterCfu100mL = well_water_cfu_100ml;
baseline_data.pondWellBlend.pondFraction = 0.5;
baseline_data.pondWellBlend.wellFraction = 0.5;
baseline_data.pondWellBlend.note = ['When usePondWellBlend is true, irrigation CFU = 0.5*pond_cfu + 0.5*well. ', ...
    'pond_cfu is surface sample (+ optional rainfall). wellWaterCfu100mL is a placeholder (0) until well sampling is enabled.'];

% --- write file (water quality, wildlife type, curing duration, volume, optional no-runoff name) ---
if use_pond_well_blend && use_rainfall_cfu_gain && curing_days == 7 && ...
        strcmp(wildlife_type, 'both') && irrigation_volume_factor == 1 && ...
        strcmp(water_quality_scenario, 'fda')
    % 50/50 pond(+rainfall)/well scenario (well placeholder may be 0)
    out_fname = 'S_irrigation_pond_well_50pct.json';
elseif strcmp(water_quality_scenario, 'unmanaged') && use_rainfall_cfu_gain && ...
        curing_days == 7 && strcmp(wildlife_type, 'both') && irrigation_volume_factor == 1 && ...
        ~use_pond_well_blend
    % Dashboard Farm Characteristics: regulatoryStandard = unmanaged
    out_fname = 'S_irrigation_unmanaged.json';
elseif strcmp(water_quality_scenario, 'non_fda') && use_rainfall_cfu_gain && ...
        curing_days == 7 && strcmp(wildlife_type, 'both') && irrigation_volume_factor == 1 && ...
        ~use_pond_well_blend
    % Dashboard Farm Characteristics: regulatoryStandard = non_fda_approved
    out_fname = 'S_irrigation_FDA_not approved.json';
elseif ~use_rainfall_cfu_gain && curing_days == 7 && strcmp(wildlife_type, 'both') && ...
        irrigation_volume_factor == 1 && ~use_pond_well_blend
    % Dashboard Farm Characteristics: rainfallRunoff = no_runoff
    out_fname = 'S_irrigation_runoff_no.json';
elseif irrigation_volume_factor == 0.75 && use_rainfall_cfu_gain && curing_days == 7 && ...
        strcmp(wildlife_type, 'both') && strcmp(water_quality_scenario, 'fda') && ~use_pond_well_blend
    % Dashboard Farm Characteristics: irrigationVolumeFactor = 0.75 (25% reduction)
    out_fname = 'S_irrigation_volume_75pct.json';
elseif irrigation_volume_factor == 0.50 && use_rainfall_cfu_gain && curing_days == 7 && ...
        strcmp(wildlife_type, 'both') && strcmp(water_quality_scenario, 'fda') && ~use_pond_well_blend
    % Dashboard Farm Characteristics: irrigationVolumeFactor = 0.50 (50% reduction)
    out_fname = 'S_irrigation_volume_50pct.json';
elseif irrigation_volume_factor == 0.25 && use_rainfall_cfu_gain && curing_days == 7 && ...
        strcmp(wildlife_type, 'both') && strcmp(water_quality_scenario, 'fda') && ~use_pond_well_blend
    % Dashboard Farm Characteristics: irrigationVolumeFactor = 0.25 (75% reduction)
    out_fname = 'S_irrigation_volume_25pct.json';
elseif curing_days ~= 7 && strcmp(wildlife_type, 'both') && irrigation_volume_factor == 1
    out_fname = sprintf('baseline_curing_%d.json', curing_days);
else
    switch wildlife_type
        case 'deer'
            out_fname = 'baseline_deer.json';
        case 'boar'
            out_fname = 'baseline_boar.json';
        otherwise
            out_fname = 'baseline.json';
    end
end
if ~use_rainfall_cfu_gain && ~strcmp(out_fname, 'S_irrigation_runoff_no.json')
    [~, base_noext, ~] = fileparts(out_fname);
    out_fname = [base_noext, '_no_runoff.json'];
end
if use_pond_well_blend && ~strcmp(out_fname, 'S_irrigation_pond_well_50pct.json')
    [~, base_noext, ~] = fileparts(out_fname);
    out_fname = [base_noext, '_pond_well_50pct.json'];
end
outpath = fullfile(export_dir, out_fname);
fid = fopen(outpath, 'w');
if fid == -1
    error('fopen failed — could not open file for writing: %s\nCheck that the export directory exists and is writable.', outpath);
end
fwrite(fid, jsonencode(baseline_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

dashboard_outpath = fullfile(dashboard_data_dir, out_fname);
copy_status = copyfile(outpath, dashboard_outpath);
if copy_status
    fprintf('    Dashboard: %s\n', dashboard_outpath);
else
    warning('Could not copy JSON to dashboard data directory: %s', dashboard_outpath);
end

fprintf('\n========== JSON EXPORT COMPLETE ==========\n');
fprintf('  File written to: %s\n', export_dir);
fprintf('  Dashboard copy: %s\n', dashboard_data_dir);
fprintf('  wildlifeType: %s\n', wildlife_type);
fprintf('  useRainfallCfuGain: %d\n', use_rainfall_cfu_gain);
fprintf('  usePondWellBlend: %d (well=%.4g CFU/100mL)\n', use_pond_well_blend, well_water_cfu_100ml);
fprintf('  (5 sensitivity/prevalence files are exported separately by File 2)\n');

% --- verification ---
fprintf('\n=== %s STRUCTURE VERIFICATION ===\n', out_fname);
b = jsondecode(fileread(outpath));
fprintf('\nTop-level fields:\n');           disp(fieldnames(b))
fprintf('wildlifeType: %s\n',               b.wildlifeType);
if isfield(b, 'rainfallRunoff')
    fprintf('rainfallRunoff.useRainfallCfuGain: %d\n', b.rainfallRunoff.useRainfallCfuGain);
end
fprintf('daily.p50 size: %dx%d\n',          size(b.daily.p50));
fprintf('irrigationDaily.p50 size: %dx%d\n', size(b.irrigationDaily.p50));
fprintf('soilPathwayDaily.p50 size: %dx%d\n', size(b.soilPathwayDaily.p50));
fprintf('thresholdByMonth.mean size: %dx%d\n', size(b.thresholdByMonth.mean));
fprintf('thresholdByMonth.thresholds: ');   disp(b.thresholdByMonth.thresholds)
fprintf('curingPeriod soilCFU.p50 size: %dx%d\n', size(b.curingPeriod.soilCFU.p50));
fprintf('curingPeriod thresh.mean size: %dx%d\n',  size(b.curingPeriod.thresholdExceedance.mean));
fprintf('onionSurface.p50 size: %dx%d\n',   size(b.onionSurface.p50));
fprintf('onionSurface.maxDuration: %d\n',   b.onionSurface.maxDuration);
fprintf('curingDecay.k size: %dx%d\n', size(b.curingDecay.k));
fprintf('histograms.irrigationLog10.counts size: %dx%d\n', size(b.histograms.irrigationLog10.counts));
fprintf('summary.medianSoilCFU: %.4e\n',     b.summary.medianSoilCFU);
fprintf('summary.medianOnionCFU: %.4e\n',   b.summary.medianOnionCFU);
fprintf('summary.medianCFU (onion KPI): %.4e\n', b.summary.medianCFU);
fprintf('pathwayContribution.irrigationPct: %.1f%%\n', b.pathwayContribution.irrigationPct);
fprintf('pathwayContribution.soilPct: %.1f%%\n', b.pathwayContribution.soilPct);
fprintf('sourceContribution.wildlifePct: %.1f%%\n', b.sourceContribution.wildlifePct);
fprintf('sourceContribution.irrigationPct: %.1f%%\n', b.sourceContribution.irrigationPct);
fprintf('sourceContribution.carryoverPct: %.1f%%\n', b.sourceContribution.carryoverPct);
fprintf('harvestTiming.curingDays: %d (run curing_days=%d)\n', b.harvestTiming.curingDays, curing_days);
if b.harvestTiming.curingDays ~= curing_days
    warning('Export curingDays (%d) does not match run parameter (%d).', b.harvestTiming.curingDays, curing_days);
end
harvest_month_idx = find(strcmp(b.thresholdByMonth.months, 'Jan'), 1);
if ~isempty(harvest_month_idx)
    jan_counts = b.thresholdByMonth.mean(harvest_month_idx, :);
    for t = 2:length(jan_counts)
        if jan_counts(t) > jan_counts(t - 1) + 1e-9
            warning('Jan threshold counts not monotonic (>=%s): %s', ...
                mat2str(b.thresholdByMonth.thresholds), mat2str(jan_counts, 3));
            break;
        end
    end
end
if isfield(b, 'wildlifeSpecies')
    fprintf('wildlifeSpecies.deerOnly.daily.p50 size: %dx%d\n', size(b.wildlifeSpecies.deerOnly.daily.p50));
    fprintf('wildlifeSpecies.boarOnly.daily.p50 size: %dx%d\n', size(b.wildlifeSpecies.boarOnly.daily.p50));
    fprintf('wildlifeSpecies.summary.deerPctOfBoth: %.1f%%\n', b.wildlifeSpecies.summary.deerPctOfBoth);
    fprintf('wildlifeSpecies.summary.boarPctOfBoth: %.1f%%\n', b.wildlifeSpecies.summary.boarPctOfBoth);
else
    fprintf('wildlifeSpecies: (not exported; run_species_attribution=false)\n');
end
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
    19,  'wildlife_species_attribution'; ...
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

function [wl_out, irr_out, carry_out] = rescale_source_pools(wl, irr, carry, total_new)
    % Keep tagged source pools aligned with combined CFU after shared decay/mixing.
    old = wl + irr + carry;
    wl_out = wl;
    irr_out = irr;
    carry_out = carry;
    mask = old > 0;
    scale = zeros(size(old));
    scale(mask) = total_new(mask) ./ old(mask);
    wl_out = wl .* scale;
    irr_out = irr .* scale;
    carry_out = carry .* scale;
end

function k_start = soil_transfer_start_day(plant_day, bulb_start_dap, undercut_day, soil_transfer_start)
    % First calendar day for soil→onion PERT transfers (Pathway 2).
    bulbing_day = plant_day + bulb_start_dap;
    if strcmp(soil_transfer_start, 'bulbing')
        k_start = bulbing_day;
    elseif strcmp(soil_transfer_start, 'undercut')
        k_start = undercut_day;
    else
        error('soil_transfer_start must be ''bulbing'' or ''undercut''');
    end
end

function pond_cfu = calculate_pond_concentration(source_cfu_100ml, wildlife_runoff_cfu, pond_volume_L)
    source_total_cfu = source_cfu_100ml * (pond_volume_L / 100);
    total_cfu = source_total_cfu + wildlife_runoff_cfu;
    pond_cfu = total_cfu / (pond_volume_L / 100);
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

function irr_schedule = onion_irrig_days(plantDay, undercutDay, establishmentDays, bulbStart, irr_stop_before_undercut, ival)
    % build irrigation schedule from growth stages; stop before undercutting
    irr_schedule = struct('doy', {}, 'stage', {});
    k = plantDay;
    idx = 0;
    undercut_dap = undercutDay - plantDay;

    while k < undercutDay
        dap = k - plantDay;

        if dap < establishmentDays
            iv = ival.Establish;
            stage = 'Establish';
        elseif dap < bulbStart
            iv = ival.Veg;
            stage = 'Veg';
        elseif dap < (undercut_dap - irr_stop_before_undercut)
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

function tf = is_wildlife_intrusion_day(day_counter, use_intrusion_schedule, intrusion_interval)
    % Returns true if wildlife feces should be added on this day.
    % When schedule is OFF: every day (original continuous deposition).
    % When schedule is ON: every intrusion_interval days; each visit uses
    % the normal daily dose (monthly/30), so fewer visits => less total feces.
    if ~use_intrusion_schedule
        tf = true;
        return;
    end
    tf = mod(day_counter - 1, intrusion_interval) == 0;
end

function subplot_cfu = distribute_wildlife_to_subplots(CFU_total, num_subplots, num_locations)
    % Deposit CFU_total at num_locations randomly chosen plants (equal split).
    % Total field CFU added per pooping event = CFU_total (conserved).
    % Return 1-by-num_subplots so it matches CFU_soil(i, :, day) row slices.
    subplot_cfu = zeros(1, num_subplots);
    n = min(num_locations, num_subplots);
    affected_plants = randperm(num_subplots, n);
    subplot_cfu(affected_plants) = CFU_total / n;
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
