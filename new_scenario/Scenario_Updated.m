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
% Irrigation water volume scale (align with Updated_Baseline.m / dashboard)
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
curing_days = 7;  % undercutting → harvest (align with Updated_Baseline.m)
if ~ismember(curing_days, [0, 3, 7, 14])
    error('curing_days must be 0, 3, 7, or 14');
end
undercut1 = har1 - curing_days;  % undercutting day per iteration
fprintf('  Irrigation stops %d day(s) before undercutting; curing = %d day(s) (undercut→harvest)\n', ...
    irr_stop_before_undercut, curing_days);

% -------------------------------------------------------------------------
% Soil → onion surface transfer window (align with Updated_Baseline.m)
% -------------------------------------------------------------------------
soil_transfer_start = 'bulbing';
soil_transfer_interval = 1;
if ~ismember(soil_transfer_start, {'bulbing', 'undercut'})
    error('soil_transfer_start must be ''bulbing'' or ''undercut''');
end
if ~(isscalar(soil_transfer_interval) && ismember(soil_transfer_interval, [1, 7]))
    error('soil_transfer_interval must be 1 (daily) or 7 (weekly)');
end
fprintf('  Soil→onion transfer: start at %s, every %d day(s), through harvest\n', ...
    soil_transfer_start, soil_transfer_interval);

% -------------------------------------------------------------------------
% Surface water quality vs FDA microbial criteria (dashboard: Water Quality)
%   water_meets_fda = true  -> GM ≤ 126 and STV ≤ 410 (dashboard fda_approved)
%   water_meets_fda = false -> GM > 126 or STV > 410  (dashboard non_fda_approved)
% Same Lognormal(2.1, 0.4) draws; only the accept/reject gate changes.
% -------------------------------------------------------------------------
water_meets_fda = true;  % manuscript / baseline default
if water_meets_fda
    fprintf('  Surface water FDA criteria: MEETS (GM≤126 and STV≤410)\n');
else
    fprintf('  Surface water FDA criteria: DOES NOT MEET (GM>126 or STV>410)\n');
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
intrusion_interval     = 1;   % manual: 1, 3, or 7 (align with Updated_Baseline.m)
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
%   Set feces_deposit_locations to 1, 10, or 20.
% -------------------------------------------------------------------------
feces_deposit_locations = 1;  % manual: 1, 10, or 20 (align with Updated_Baseline.m default)
if ~ismember(feces_deposit_locations, [1, 10, 20])
    error('feces_deposit_locations must be 1, 10, or 20');
end
fprintf('  Feces deposit locations: %d (total CFU conserved per pooping event)\n', ...
    feces_deposit_locations);

% -------------------------------------------------------------------------
% Pond + well blend (manual switch; default OFF so other scenarios unchanged)
%   false -> irrigation CFU = pond/surface + rainfall (as before)
%   true  -> irrigation CFU = 0.5 * pond_cfu + 0.5 * well_cfu
%            pond_cfu = surface sample + rainfall gain
%            well_cfu = well_water_cfu_100ml (placeholder 0 until well sampling enabled)
% Stored in irrigation_concentrations_crop1, so all downstream replays inherit it.
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

K = 254 * area_per_plant; % 1 in water = 25.4 L/m^2

% Racine et al. prevalence
prev_min = [78.40, 15.27, 0.464];

% curing decay — Racine et al.
% k = log10 daily decay rate on onion surface (log10/day)
% Normal distribution directly from Racine study
% mean = 0.0983, SD = 0.0111 log10/day
curing_k_dist = makedist('Normal', 'mu', 0.0983, 'sigma', 0.0111);
% curing_mpn0 is NOT sampled here — it comes from model soil CFU
% at undercutting, filled after the soil year (mirrors Updated_Baseline Pathway 2)
curing_k     = zeros(iterations, 1);
curing_mpn14 = zeros(iterations, 1);
curing_mpn0  = zeros(iterations, 1);  % filled after the soil year (Updated_Baseline Pathway 2)

fprintf('\nPre-computing curing decay rates for %d iterations...\n', iterations);

for i = 1:iterations
    % sample k directly from Normal distribution
    k           = random(curing_k_dist, 1);
    curing_k(i) = k;
end

fprintf('  k (log10/day): mean=%.4f, std=%.4f\n', mean(curing_k), std(curing_k));
fprintf('  k range P5-P95: [%.4f, %.4f]\n', prctile(curing_k,5), prctile(curing_k,95));
fprintf('  MPN(0) and MPN(14) computed per-iteration from soil CFU at undercutting\n');

% monthly soil decay rates (log10CFU/day) - from 10 year from 2016-2025 weather data
% reordered to Jul->Jun
monthly_decay = [-0.07303333,-0.07303333,-0.0793,-0.0793,-0.0793,-0.0793, -0.07953333,-0.07953333,-0.07953333,-0.07953333,-0.07303333, -0.07303333];

% rainfall (mm, Vidalia) - also Jul->Jun rainfall_monthly
rainfall_monthly = [4.408141935, 6.107651613, 2.565386667, 1.365058065, 2.385986667, 2.407354839, 3.441123871,3.491887192, 3.723316129, 2.926093333, 5.046980645, 3.720293333];

% Shared soil -> onion transfer distribution for every scenario.
% Keep one definition so all scenario families use identical mechanics.
pert_min_onion  = 0.0036;
pert_mode_onion = 0.0036;
pert_max_onion  = 0.0585;
pert_lambda_onion = 4;
pert_alpha1_onion = 1 + pert_lambda_onion * ...
    (pert_mode_onion - pert_min_onion) / (pert_max_onion - pert_min_onion);
pert_alpha2_onion = 1 + pert_lambda_onion * ...
    (pert_max_onion - pert_mode_onion) / (pert_max_onion - pert_min_onion);
beta_dist_onion = makedist('Beta', 'a', pert_alpha1_onion, 'b', pert_alpha2_onion);

% Self-consistent carryover: if a prior run already fit this scenario file's
% own end-of-June CFU distribution, load and reuse it. Otherwise fall back
% to the initial literature-based guess. Saved under a scenario-specific
% filename (see Section 3.5) so it never clobbers / is clobbered by
% Updated_Baseline.m's own june_end_cfu_distribution.mat.
scenario_june_end_matfile = 'scenario_june_end_cfu_distribution.mat';
if exist(scenario_june_end_matfile, 'file')
    prior_fit = load(scenario_june_end_matfile, 'mu_fit', 'sigma_fit');
    june_end_dist = makedist('Lognormal', prior_fit.mu_fit, prior_fit.sigma_fit);
    fprintf('  june_end_dist: loaded self-consistent fit from prior run (mu=%.4f, sigma=%.4f)\n', ...
        prior_fit.mu_fit, prior_fit.sigma_fit);
else
    june_end_dist = makedist('Lognormal', -0.7282, 0.3465);
    fprintf('  june_end_dist: no prior run found — using initial literature-based seed (mu=-0.7282, sigma=0.3465)\n');
end

fprintf('  Iterations: %d\n', iterations);
fprintf('  Plants: %d\n', plantnum);
fprintf('  Area per plant: %.4f m\xc2\xb2\n', area_per_plant);

%% ========================================================================
%  SECTION 2: WILDLIFE FECAL CONTAMINATION
%% ========================================================================
fprintf('\nGenerating wildlife fecal contamination...\n');

deer_seasonal_weight = [734.0616, 734.0616, 1171.5387, 1171.5387, 1171.5387, 1171.5387, ...
                        440.7372, 440.7372, 440.7372, 440.7372, 425.25, 425.25];

pd = makedist('lognormal', 5.95, 0.90);
td = makedist('Triangular', 'a', 0.012, 'b', (0.012+0.06)/2, 'c', 0.06);

CFU_deer = zeros(iterations, 12);
for month = 1:12
    cont_feral = random(pd, iterations, 1);
    pop_dens   = random(td, iterations, 1);
    amt_fecal  = deer_seasonal_weight(month) * pop_dens;
    CFU_deer(:, month) = amt_fecal .* cont_feral;
end

% Wild Boar — replaces wild pig and feral pig (consolidated)
% Fecal E. coli: mean = 7.4965 log10 CFU/g, SD = 1.079 log10 CFU/g
% Converted to natural log for makedist:
%   mu    = 7.4965 * ln(10) = 17.2613
%   sigma = 1.079  * ln(10) = 2.4845
wild_boar_seasonal_weight = repmat(1121, 1, 12);

pd_wild_boar = makedist('lognormal', 7.4965, 1.079);
td_wild_boar = makedist('Triangular', 'a', 0.003397, 'b', (0.003397+0.022605)/2, 'c', 0.022605);

CFU_wild_boar = zeros(iterations, 12);
for month = 1:12
    cont_wild_boar       = random(pd_wild_boar, iterations, 1);
    defec_rate_wild_boar = random(td_wild_boar, iterations, 1);
    amt_wild_boar        = wild_boar_seasonal_weight(month) * defec_rate_wild_boar;
    CFU_wild_boar(:, month) = amt_wild_boar .* cont_wild_boar;
end

fprintf('  Deer fecal: 12 months generated\n');
fprintf('  Wild Boar: 12 months generated\n');

%% ========================================================================
%  SECTION 3: SOIL CONTAMINATION BUILD-UP
%% ========================================================================
fprintf('\nBuilding soil contamination matrix (CFU_soil)...\n');

CFU_soil = zeros(iterations, plantnum, 365);

fprintf('  Part 0: Previous year carryover...\n');
for i = 1:iterations
    carryover = random(june_end_dist, 1);
    CFU_soil(i, :, 1) = carryover;
end

fprintf('  Part 1: Pre-crop 1 accumulation...\n');
for i = 1:iterations
    for k = 1:(plant1(i) - 1)
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end
        daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
        if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            daily_input = 0;
        end
        CFU_soil(i, :, next_day_idx) = CFU_soil(i, :, day_idx) + daily_input;
        CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
    end
end

fprintf('  Part 2: During crop 1 (plant-level contamination)...\n');

% pre-generate 20 irrigation water samples per iteration (FDA gate via water_meets_fda)
% lognormal(2.1, 0.4); FDA Produce Safety Rule: GM 126, STV 410 CFU/100mL
irr_dist     = makedist('Lognormal', 2.1, 0.4);
n_irr_samples = 20;
GM_limit     = 126;
STV_limit    = 410;
max_wq_attempts = 10000;

irr_source_samples = cell(iterations, 1);
irr_GM  = zeros(iterations, 1);
irr_STV = zeros(iterations, 1);

if water_meets_fda
    fprintf('    Generating FDA-compliant water quality sets (20 samples each)...\n');
else
    fprintf('    Generating FDA-noncompliant water quality sets (20 samples each)...\n');
end
for i = 1:iterations
    accepted   = false;
    n_attempts = 0;
    while ~accepted
        n_attempts = n_attempts + 1;
        if n_attempts > max_wq_attempts
            error('water quality sampling: no accepted set after %d attempts (water_meets_fda=%d)', ...
                max_wq_attempts, water_meets_fda);
        end
        C_samples  = random(irr_dist, n_irr_samples, 1);
        log10_C    = log10(C_samples);
        x_bar      = mean(log10_C);
        s          = std(log10_C);
        GM         = 10^x_bar;
        STV        = 10^(x_bar + 1.2816 * s);
        meets = (GM <= GM_limit) && (STV <= STV_limit);
        if water_meets_fda
            accepted = meets;
        else
            accepted = ~meets;  % GM > 126 or STV > 410
        end
    end
    irr_source_samples{i} = C_samples;
    irr_GM(i)  = GM;
    irr_STV(i) = STV;
    fprintf('    Iter %d: GM=%.2f, STV=%.2f (accepted after %d draw(s))\n', i, GM, STV, n_attempts);
    fprintf('      20 samples (CFU/100mL): ');
    fprintf('%.1f ', C_samples);
    fprintf('\n');
end
fprintf('    GM range: [%.1f, %.1f] (limit: %d)\n', min(irr_GM), max(irr_GM), GM_limit);
fprintf('    STV range: [%.1f, %.1f] (limit: %d)\n', min(irr_STV), max(irr_STV), STV_limit);

irrigation_schedule_crop1     = cell(iterations, 1);
irrigation_concentrations_crop1 = cell(iterations, 1);

for i = 1:iterations
    irr_events  = onion_irrig_days(plant1(i), undercut1(i), establishment_days(i), ...
        bulb_start(i), irr_stop_before_undercut, ival);
    irrigation_schedule_crop1{i} = irr_events;
    irr_day_list = [irr_events.doy];
    source_cfu_per_event = zeros(length(irr_events), 1);

    for k = plant1(i):(har1(i) - 1)
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end

        if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
            wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);

            wildlife_cfu_per_plant = (deer_per_plant + wild_boar_per_plant) / 30;
            CFU_soil(i, :, day_idx) = CFU_soil(i, :, day_idx) + wildlife_cfu_per_plant;
        end

        if ismember(k, irr_day_list)
            event_idx = find([irr_events.doy] == k, 1);
            stage     = irr_events(event_idx).stage;
            rainfall_amount_mm  = rainfall_monthly(month);
            cfu_gain_from_rainfall = calculate_rainfall_cfu_gain(rainfall_amount_mm);
            sample_idx          = mod(event_idx - 1, n_irr_samples) + 1;
            source_baseline_cfu = irr_source_samples{i}(sample_idx);
            pond_cfu            = source_baseline_cfu + cfu_gain_from_rainfall;
            if use_pond_well_blend
                source_cfu_100ml = 0.5 * pond_cfu + 0.5 * well_water_cfu_100ml;
            else
                source_cfu_100ml = pond_cfu;
            end
            source_cfu_per_event(event_idx) = source_cfu_100ml;
            irr_depth_in        = depth_for_stage(stage, depth) * irrigation_volume_factor;
            water_per_plant_L   = irr_depth_in * 25.4 * area_per_plant;
            cfu_irrigation_per_plant = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
            CFU_soil(i, :, day_idx) = CFU_soil(i, :, day_idx) + cfu_irrigation_per_plant;
        end

        if day_idx < 365
            CFU_soil(i, :, next_day_idx) = 10.^(log10(CFU_soil(i, :, day_idx) + 1e-10) + monthly_decay(month));
        else
            CFU_soil(i, :, 1) = 10.^(log10(CFU_soil(i, :, 365) + 1e-10) + monthly_decay(month));
        end
    end
    irrigation_concentrations_crop1{i} = source_cfu_per_event;
    if mod(i, 50) == 0
        fprintf('    Iteration %d complete\n', i);
    end
end

fprintf('  Part 3: Ground preparation post-crop 1...\n');
for i = 1:iterations
    har_day_idx = mod(har1(i) - 1, 365) + 1;
    mean_cfu    = mean(CFU_soil(i, :, har_day_idx));
    CFU_soil(i, :, har_day_idx) = mean_cfu;
    for k = har1(i):365
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end
        daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
        if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            daily_input = 0;
        end
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

CFU_daily = zeros(iterations, 365);
for i = 1:iterations
    for day = 1:365
        CFU_daily(i, day) = mean(CFU_soil(i, :, day));
    end
end

fprintf('  Daily CFU matrix created: [%d iterations x %d days]\n', iterations, 365);
fprintf('  Mean CFU across all days: %.2e\n', mean(CFU_daily(:)));
fprintf('  Max daily CFU: %.2e (Day %d, Iter %d)\n', ...
        max(CFU_daily(:)), find(CFU_daily == max(CFU_daily(:)), 1));

daily_mean = mean(CFU_daily, 1);
daily_std  = std(CFU_daily, 0, 1);
daily_max  = max(CFU_daily, [], 1);
fprintf('  Daily statistics calculated\n');

% --- self-consistent carryover fit: refit end-of-June CFU distribution ---
% (mirrors Updated_Baseline.m; saved under a scenario-specific filename so
% this file's fit never overwrites/is overwritten by the main baseline run)
june_end_cfu = CFU_daily(:, 365);
ln_vals      = log(june_end_cfu + 1e-10);
mu_fit       = mean(ln_vals);
sigma_fit    = std(ln_vals);
fprintf('  june_end_dist fit (this run): mu=%.4f, sigma=%.4f\n', mu_fit, sigma_fit);
save(scenario_june_end_matfile, 'june_end_cfu', 'mu_fit', 'sigma_fit');

% Diagnostic Racine curing (mirrors Updated_Baseline Pathway 2).
% Uses soil CFU at undercutting; k is NOT applied to harvest onion CFU.
fprintf('  Computing diagnostic curing MPN from soil CFU at undercutting...\n');
for i = 1:iterations
    undercut_day_idx = mod(undercut1(i) - 1, 365) + 1;
    soil_at_undercut = reshape(CFU_soil(i, :, undercut_day_idx), 1, plantnum);
    mpn0_plants = zeros(1, plantnum);
    pos = soil_at_undercut > 0;
    mpn0_plants(pos) = log10(soil_at_undercut(pos));
    curing_mpn0(i)  = mean(mpn0_plants);
    curing_mpn14(i) = mean(max(0, mpn0_plants - curing_k(i) * curing_days));
end
fprintf('  Curing MPN(0) from model soil (field mean): mean=%.4f, std=%.4f\n', ...
    mean(curing_mpn0), std(curing_mpn0));
fprintf('  Harvest MPN log10 (after %d curing days, field mean): mean=%.4f, std=%.4f\n', ...
    curing_days, mean(curing_mpn14), std(curing_mpn14));
fprintf('  Fraction of iterations with field-mean MPN(14)=0: %.1f%%\n', ...
    sum(curing_mpn14 == 0) / iterations * 100);

% Final onion CFU for the main combined-source scenario.
% Preserve RNG so adding this output does not shift downstream scenario draws.
fprintf('  Calculating final onion CFU for main combined-source scenario...\n');
onion_rng_state = rng;
CFU_onion_baseline = soil_to_onion_harvest(CFU_soil, plant1, har1, undercut1, ...
    bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
    beta_dist_onion, pert_min_onion, pert_max_onion);
rng(onion_rng_state);
onion_baseline_stats = summarize_harvest_onion(CFU_onion_baseline);
clear CFU_onion_baseline CFU_soil;

%% ========================================================================
%  SECTION 12: SCENARIO ANALYSIS
%% ========================================================================
fprintf('\n========== SCENARIO ANALYSIS: IRRIGATION vs WILDLIFE ==========\n');

% --- SCENARIO 1: IRRIGATION ONLY ---
fprintf('\n--- Scenario 1: Irrigation Only ---\n');
CFU_soil_irrig_only = zeros(iterations, plantnum, 365);

for i = 1:iterations
    CFU_soil_irrig_only(i, :, 1) = random(june_end_dist, 1);
end
for i = 1:iterations
    for k = 1:(plant1(i) - 1)
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end
        CFU_soil_irrig_only(i, :, next_day_idx) = 10.^(log10(CFU_soil_irrig_only(i, :, day_idx) + 1e-10) + monthly_decay(month));
    end
end

for i = 1:iterations
    irr_events       = irrigation_schedule_crop1{i};
    irr_day_list     = [irr_events.doy];
    source_cfu_values = irrigation_concentrations_crop1{i};

    for k = plant1(i):(har1(i) - 1)
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end

        if ismember(k, irr_day_list)
            event_idx = find([irr_events.doy] == k, 1);
            stage     = irr_events(event_idx).stage;
            source_cfu_100ml  = source_cfu_values(event_idx);
            irr_depth_in      = depth_for_stage(stage, depth) * irrigation_volume_factor;
            water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
            cfu_irrigation_per_plant = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
            CFU_soil_irrig_only(i, :, day_idx) = CFU_soil_irrig_only(i, :, day_idx) + cfu_irrigation_per_plant;
        end

        if day_idx < 365
            CFU_soil_irrig_only(i, :, next_day_idx) = 10.^(log10(CFU_soil_irrig_only(i, :, day_idx) + 1e-10) + monthly_decay(month));
        else
            CFU_soil_irrig_only(i, :, 1) = 10.^(log10(CFU_soil_irrig_only(i, :, 365) + 1e-10) + monthly_decay(month));
        end
    end

    har_day_idx = mod(har1(i) - 1, 365) + 1;
    mean_cfu    = mean(CFU_soil_irrig_only(i, :, har_day_idx));
    CFU_soil_irrig_only(i, :, har_day_idx) = mean_cfu;
    for k = har1(i):365
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end
        if next_day_idx > day_idx
            CFU_soil_irrig_only(i, :, next_day_idx) = 10.^(log10(CFU_soil_irrig_only(i, :, day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    if mod(i, 50) == 0
        fprintf('  Scenario 1: Iteration %d/%d complete\n', i, iterations);
    end
end

CFU_daily_irrig_only = zeros(iterations, 365);
for i = 1:iterations
    for day = 1:365
        CFU_daily_irrig_only(i, day) = mean(CFU_soil_irrig_only(i, :, day));
    end
end
fprintf('  Irrigation-only matrix: [%d x %d]\n', iterations, 365);
fprintf('  Mean CFU: %.2e | Max CFU: %.2e\n', mean(CFU_daily_irrig_only(:)), max(CFU_daily_irrig_only(:)));
fprintf('  Calculating final onion CFU for irrigation-only scenario...\n');
onion_rng_state = rng;
CFU_onion_irrig_only = soil_to_onion_harvest(CFU_soil_irrig_only, plant1, har1, undercut1, ...
    bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
    beta_dist_onion, pert_min_onion, pert_max_onion);
rng(onion_rng_state);
onion_irrig_only_stats = summarize_harvest_onion(CFU_onion_irrig_only);
clear CFU_onion_irrig_only CFU_soil_irrig_only;

% --- SCENARIO 2: WILDLIFE ONLY ---
fprintf('\n--- Scenario 2: Wildlife Only ---\n');
CFU_soil_wildlife_only = zeros(iterations, plantnum, 365);

for i = 1:iterations
    CFU_soil_wildlife_only(i, :, 1) = random(june_end_dist, 1);
end

for i = 1:iterations
    for k = 1:(plant1(i) - 1)
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end
        daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
        if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            daily_input = 0;
        end
        CFU_soil_wildlife_only(i, :, next_day_idx) = CFU_soil_wildlife_only(i, :, day_idx) + daily_input;
        CFU_soil_wildlife_only(i, :, next_day_idx) = 10.^(log10(CFU_soil_wildlife_only(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
    end
end

for i = 1:iterations
    for k = plant1(i):(har1(i) - 1)
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end

        if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
            wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
            wildlife_cfu = (deer_per_plant + wild_boar_per_plant) / 30;
            CFU_soil_wildlife_only(i, :, day_idx) = CFU_soil_wildlife_only(i, :, day_idx) + wildlife_cfu;
        end

        if day_idx < 365
            CFU_soil_wildlife_only(i, :, next_day_idx) = 10.^(log10(CFU_soil_wildlife_only(i, :, day_idx) + 1e-10) + monthly_decay(month));
        else
            CFU_soil_wildlife_only(i, :, 1) = 10.^(log10(CFU_soil_wildlife_only(i, :, 365) + 1e-10) + monthly_decay(month));
        end
    end

    har_day_idx = mod(har1(i) - 1, 365) + 1;
    mean_cfu    = mean(CFU_soil_wildlife_only(i, :, har_day_idx));
    CFU_soil_wildlife_only(i, :, har_day_idx) = mean_cfu;
    for k = har1(i):365
        day_idx      = mod(k - 1, 365) + 1;
        next_day_idx = mod(k, 365) + 1;
        month = get_month_index_jul_start(day_idx);
        if month > 12, month = 12; end
        daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
        if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
            daily_input = 0;
        end
        if next_day_idx > day_idx
            CFU_soil_wildlife_only(i, :, next_day_idx) = CFU_soil_wildlife_only(i, :, day_idx) + daily_input;
            CFU_soil_wildlife_only(i, :, next_day_idx) = 10.^(log10(CFU_soil_wildlife_only(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    if mod(i, 50) == 0
        fprintf('  Scenario 2: Iteration %d/%d complete\n', i, iterations);
    end
end

CFU_daily_wildlife_only = zeros(iterations, 365);
for i = 1:iterations
    for day = 1:365
        CFU_daily_wildlife_only(i, day) = mean(CFU_soil_wildlife_only(i, :, day));
    end
end
fprintf('  Wildlife-only matrix: [%d x %d]\n', iterations, 365);
fprintf('  Mean CFU: %.2e | Max CFU: %.2e\n', mean(CFU_daily_wildlife_only(:)), max(CFU_daily_wildlife_only(:)));
fprintf('  Calculating final onion CFU for wildlife-only scenario...\n');
onion_rng_state = rng;
CFU_onion_wildlife_only = soil_to_onion_harvest(CFU_soil_wildlife_only, plant1, har1, undercut1, ...
    bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
    beta_dist_onion, pert_min_onion, pert_max_onion);
rng(onion_rng_state);
onion_wildlife_only_stats = summarize_harvest_onion(CFU_onion_wildlife_only);
clear CFU_onion_wildlife_only CFU_soil_wildlife_only;

% --- SCENARIO 2b: WILDLIFE SPECIES ATTRIBUTION (deer-only / boar-only) ---
% Isolated from CFU_daily / wildlife-only "both". Irrigation OFF (matches wildlife-only).
fprintf('\n--- Scenario 2b: Wildlife Species Attribution (irrigation OFF) ---\n');
fprintf('  Main wildlife-only (both species) left unchanged.\n');

species_labels = {'deer_only', 'boar_only'};
deer_factor    = [1, 0];
boar_factor    = [0, 1];

CFU_daily_deer_only = zeros(iterations, 365);
CFU_daily_boar_only = zeros(iterations, 365);

for s = 1:2
    df = deer_factor(s);
    bf = boar_factor(s);
    fprintf('  Running %s (deer=%.0f, boar=%.0f)...\n', species_labels{s}, df, bf);

    CFU_soil_sp = zeros(iterations, plantnum, 365);

    % Carryover: same June-end lognormal as the main baseline (no extra initial decay)
    for i = 1:iterations
        CFU_soil_sp(i, :, 1) = random(june_end_dist, 1);
    end

    % Pre-crop
    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
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

    % During crop (wildlife only — no irrigation)
    for i = 1:iterations
        for k = plant1(i):(har1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end

            if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                deer_per_plant      = distribute_wildlife_to_subplots(df * CFU_deer(i, month), plantnum, feces_deposit_locations);
                wild_boar_per_plant = distribute_wildlife_to_subplots(bf * CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                wildlife_cfu = (deer_per_plant + wild_boar_per_plant) / 30;
                CFU_soil_sp(i, :, day_idx) = CFU_soil_sp(i, :, day_idx) + wildlife_cfu;
            end

            if day_idx < 365
                CFU_soil_sp(i, :, next_day_idx) = 10.^(log10(CFU_soil_sp(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_sp(i, :, 1) = 10.^(log10(CFU_soil_sp(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end

        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu    = mean(CFU_soil_sp(i, :, har_day_idx));
        CFU_soil_sp(i, :, har_day_idx) = mean_cfu;
        for k = har1(i):365
            day_idx      = mod(k - 1, 365) + 1;
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

        if mod(i, 50) == 0
            fprintf('    %s: Iteration %d/%d complete\n', species_labels{s}, i, iterations);
        end
    end

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
    onion_rng_state = rng;
    CFU_onion_sp = soil_to_onion_harvest(CFU_soil_sp, plant1, har1, undercut1, ...
        bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
        beta_dist_onion, pert_min_onion, pert_max_onion);
    rng(onion_rng_state);
    if s == 1
        onion_deer_only_stats = summarize_harvest_onion(CFU_onion_sp);
    else
        onion_boar_only_stats = summarize_harvest_onion(CFU_onion_sp);
    end
    clear CFU_onion_sp CFU_soil_sp CFU_daily_sp;
end

mean_wl_both = mean(CFU_daily_wildlife_only(:));
mean_wl_deer = mean(CFU_daily_deer_only(:));
mean_wl_boar = mean(CFU_daily_boar_only(:));
fprintf('\n  Species attribution summary (mean soil CFU, irrigation OFF):\n');
fprintf('    Wildlife both: %.4e\n', mean_wl_both);
fprintf('    Deer only:     %.4e  (%.1f%% of wildlife-both)\n', mean_wl_deer, mean_wl_deer / mean_wl_both * 100);
fprintf('    Boar only:     %.4e  (%.1f%% of wildlife-both)\n', mean_wl_boar, mean_wl_boar / mean_wl_both * 100);
fprintf('    (Shares may not sum to 100%% due to nonlinear decay)\n');

% --- Compute percentiles ---
fprintf('\nComputing percentiles for both scenarios...\n');
irrig_only_pct  = zeros(7, 365);
wildlife_only_pct = zeros(7, 365);
baseline_pct    = zeros(7, 365);
deer_only_pct   = zeros(7, 365);
boar_only_pct   = zeros(7, 365);

for d = 1:365
    vals = CFU_daily_irrig_only(:, d);
    irrig_only_pct(1,d) = min(vals);   irrig_only_pct(2,d) = prctile(vals,5);
    irrig_only_pct(3,d) = prctile(vals,25); irrig_only_pct(4,d) = prctile(vals,50);
    irrig_only_pct(5,d) = prctile(vals,75); irrig_only_pct(6,d) = prctile(vals,95);
    irrig_only_pct(7,d) = max(vals);

    vals = CFU_daily_wildlife_only(:, d);
    wildlife_only_pct(1,d) = min(vals);   wildlife_only_pct(2,d) = prctile(vals,5);
    wildlife_only_pct(3,d) = prctile(vals,25); wildlife_only_pct(4,d) = prctile(vals,50);
    wildlife_only_pct(5,d) = prctile(vals,75); wildlife_only_pct(6,d) = prctile(vals,95);
    wildlife_only_pct(7,d) = max(vals);

    vals = CFU_daily(:, d);
    baseline_pct(1,d) = min(vals);   baseline_pct(2,d) = prctile(vals,5);
    baseline_pct(3,d) = prctile(vals,25); baseline_pct(4,d) = prctile(vals,50);
    baseline_pct(5,d) = prctile(vals,75); baseline_pct(6,d) = prctile(vals,95);
    baseline_pct(7,d) = max(vals);

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
end
fprintf('  Percentiles computed.\n');

% Plot styling
pct_labels = {'Min', '25th Percentile', '50th Percentile (Median)', ...
              '75th Percentile', '95th Percentile', 'Max'};
pct_colors = [0.6 0.6 0.6; 0.0 0.3 0.7; 0.9 0.0 0.0; 1.0 0.5 0.0; 0.6 0.0 0.6; 0.2 0.2 0.2];
pct_styles = {':', '-.', '-', '-.', '--', ':'};
pct_widths = [1.0, 1.5, 2.5, 1.5, 1.2, 1.0];
plot_rows  = [1, 3, 4, 5, 6, 7];

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
days   = 1:365;

% Figure 21: Irrigation Only
figure(21); clf;
for p = 1:6
    plot(days, log10(irrig_only_pct(plot_rows(p),:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), 'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end
fill([days, fliplr(days)], [log10(irrig_only_pct(5,:)+1), fliplr(log10(irrig_only_pct(3,:)+1))], ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Scenario 1: Soil E. coli - Irrigation Only (No Wildlife)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1), xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off'); end
fprintf('  Figure 21 created: Irrigation-only scenario\n');

% Figure 22: Wildlife Only
figure(22); clf;
for p = 1:6
    plot(days, log10(wildlife_only_pct(plot_rows(p),:) + 1), pct_styles{p}, ...
        'Color', pct_colors(p,:), 'LineWidth', pct_widths(p), 'DisplayName', pct_labels{p});
    if p == 1, hold on; end
end
fill([days, fliplr(days)], [log10(wildlife_only_pct(5,:)+1), fliplr(log10(wildlife_only_pct(3,:)+1))], ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Scenario 2: Soil E. coli - Wildlife Only (No Irrigation)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1), xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off'); end
fprintf('  Figure 22 created: Wildlife-only scenario\n');

% Figure 23: Three-scenario median comparison
figure(23); clf;
plot(days, log10(baseline_pct(4,:) + 1), 'k-', 'LineWidth', 2.5, 'DisplayName', 'Baseline (Both Sources)'); hold on;
plot(days, log10(irrig_only_pct(4,:) + 1), 'b--', 'LineWidth', 2.0, 'DisplayName', 'Irrigation Only');
plot(days, log10(wildlife_only_pct(4,:) + 1), 'r-.', 'LineWidth', 2.0, 'DisplayName', 'Wildlife Only');
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12); ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Scenario Comparison: Median Soil E. coli per Subplot', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1), xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off'); end
fprintf('  Figure 23 created: Three-scenario median comparison\n');

% Figure 24: Side-by-side with percentile bands
figure(24); clf;
subplot(3,1,1);
plot(days, log10(baseline_pct(4,:)+1), 'k-', 'LineWidth', 2, 'DisplayName', 'Median'); hold on;
fill([days, fliplr(days)], [log10(baseline_pct(5,:)+1), fliplr(log10(baseline_pct(3,:)+1))], [0.5 0.5 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(days, log10(baseline_pct(7,:)+1), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8, 'DisplayName', 'Max');
plot(days, log10(baseline_pct(1,:)+1), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8, 'DisplayName', 'Min'); hold off;
ylabel('log_{10}(CFU+1)', 'FontSize', 10); title('Baseline: Wildlife + Irrigation', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(3,1,2);
plot(days, log10(irrig_only_pct(4,:)+1), 'b-', 'LineWidth', 2, 'DisplayName', 'Median'); hold on;
fill([days, fliplr(days)], [log10(irrig_only_pct(5,:)+1), fliplr(log10(irrig_only_pct(3,:)+1))], [0.2 0.4 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(days, log10(irrig_only_pct(7,:)+1), ':', 'Color', [0.0 0.3 0.6], 'LineWidth', 0.8, 'DisplayName', 'Max');
plot(days, log10(irrig_only_pct(1,:)+1), ':', 'Color', [0.0 0.3 0.6], 'LineWidth', 0.8, 'DisplayName', 'Min'); hold off;
ylabel('log_{10}(CFU+1)', 'FontSize', 10); title('Scenario 1: Irrigation Only', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(3,1,3);
plot(days, log10(wildlife_only_pct(4,:)+1), 'r-', 'LineWidth', 2, 'DisplayName', 'Median'); hold on;
fill([days, fliplr(days)], [log10(wildlife_only_pct(5,:)+1), fliplr(log10(wildlife_only_pct(3,:)+1))], [0.8 0.2 0.2], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(days, log10(wildlife_only_pct(7,:)+1), ':', 'Color', [0.6 0.0 0.0], 'LineWidth', 0.8, 'DisplayName', 'Max');
plot(days, log10(wildlife_only_pct(1,:)+1), ':', 'Color', [0.6 0.0 0.0], 'LineWidth', 0.8, 'DisplayName', 'Min'); hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12); ylabel('log_{10}(CFU+1)', 'FontSize', 10);
title('Scenario 2: Wildlife Only', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
sgtitle('Soil E. coli Scenario Comparison: Contribution by Source', 'FontSize', 14, 'FontWeight', 'bold');
fprintf('  Figure 24 created: 3-panel scenario comparison\n');

fprintf('\n--- Scenario Summary (Median CFU across all days) ---\n');
fprintf('  %-25s  %12.4e\n', 'Baseline (both sources)', median(CFU_daily(:)));
fprintf('  %-25s  %12.4e\n', 'Irrigation only', median(CFU_daily_irrig_only(:)));
fprintf('  %-25s  %12.4e\n', 'Wildlife only', median(CFU_daily_wildlife_only(:)));
fprintf('  %-25s  %12.4e\n', 'Deer only (no irrig)', median(CFU_daily_deer_only(:)));
fprintf('  %-25s  %12.4e\n', 'Boar only (no irrig)', median(CFU_daily_boar_only(:)));
irrig_contrib   = mean(CFU_daily_irrig_only(:)) / mean(CFU_daily(:)) * 100;
wildlife_contrib = mean(CFU_daily_wildlife_only(:)) / mean(CFU_daily(:)) * 100;
fprintf('\n  Approximate contributions to total soil CFU:\n');
fprintf('    Irrigation: %.1f%%\n', irrig_contrib);
fprintf('    Wildlife:   %.1f%%\n', wildlife_contrib);
fprintf('    (Note: contributions may not sum to 100%% due to nonlinear decay interactions)\n');

% Figure 19: wildlife species attribution (irrigation OFF)
figure(19); clf;
plot(days, log10(wildlife_only_pct(4,:) + 1), 'k-', 'LineWidth', 2.5, 'DisplayName', 'Wildlife both (deer + boar)'); hold on;
plot(days, log10(deer_only_pct(4,:) + 1), 'Color', [0.2 0.55 0.25], 'LineStyle', '-', 'LineWidth', 2.0, 'DisplayName', 'Deer only');
plot(days, log10(boar_only_pct(4,:) + 1), 'Color', [0.75 0.35 0.1], 'LineStyle', '-.', 'LineWidth', 2.0, 'DisplayName', 'Boar only');
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12);
ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Wildlife Species Attribution: Median Soil CFU (Irrigation OFF)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1)
    xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
end
fprintf('  Figure 19 created: wildlife species attribution\n');
fprintf('\n========== SCENARIO ANALYSIS COMPLETE ==========\n');

%% ========================================================================
%  SECTION 13: SENSITIVITY ANALYSIS
%% ========================================================================
fprintf('\n========== SENSITIVITY ANALYSIS ==========\n');

reduction_levels = [0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0];
n_levels         = length(reduction_levels);
level_labels     = {'20%','40%','60%','80%','100%','120%','140%','160%','180%','200%'};

% threshold storage - overall
%thresholds_sa = [10, 20, 50, 100];
thresholds_sa = [1, 5, 10, 20];
n_thresh_sa   = length(thresholds_sa);
SA_wildlife_thresh = zeros(n_levels, n_thresh_sa);
SA_irrig_thresh    = zeros(n_levels, n_thresh_sa);

% threshold storage - by harvest month
% _monthly      = mean plants per iteration per month
% _monthly_total = total plants summed across iterations per month
% _monthly_iters = number of iterations that fell in that month
SA_wildlife_thresh_monthly       = zeros(n_levels, 12, n_thresh_sa);
SA_irrig_thresh_monthly          = zeros(n_levels, 12, n_thresh_sa);
SA_wildlife_thresh_monthly_total = zeros(n_levels, 12, n_thresh_sa);
SA_irrig_thresh_monthly_total    = zeros(n_levels, 12, n_thresh_sa);
SA_wildlife_thresh_monthly_iters = zeros(n_levels, 12);
SA_irrig_thresh_monthly_iters    = zeros(n_levels, 12);

% Reuse the shared PERT distribution for all scenario families.
fprintf('  PERT transfer distribution: alpha1=%.4f, alpha2=%.4f\n', ...
    pert_alpha1_onion, pert_alpha2_onion);

% Final harvest-onion summaries for each source-intensity level.
SA_wildlife_onion_mean   = zeros(n_levels, 1);
SA_wildlife_onion_median = zeros(n_levels, 1);
SA_wildlife_onion_max    = zeros(n_levels, 1);
SA_irrig_onion_mean      = zeros(n_levels, 1);
SA_irrig_onion_median    = zeros(n_levels, 1);
SA_irrig_onion_max       = zeros(n_levels, 1);

% 7-band percentile matrices
SA_wildlife_min    = zeros(n_levels, 365);
SA_wildlife_p05    = zeros(n_levels, 365);
SA_wildlife_p25    = zeros(n_levels, 365);
SA_wildlife_median = zeros(n_levels, 365);
SA_wildlife_p75    = zeros(n_levels, 365);
SA_wildlife_p95    = zeros(n_levels, 365);
SA_wildlife_max    = zeros(n_levels, 365);

SA_irrig_min    = zeros(n_levels, 365);
SA_irrig_p05    = zeros(n_levels, 365);
SA_irrig_p25    = zeros(n_levels, 365);
SA_irrig_median = zeros(n_levels, 365);
SA_irrig_p75    = zeros(n_levels, 365);
SA_irrig_p95    = zeros(n_levels, 365);
SA_irrig_max    = zeros(n_levels, 365);

% =====================================================================
%  ANALYSIS 1: WILDLIFE REDUCTION (Irrigation stays at 100%)
% =====================================================================
fprintf('\n--- Analysis 1: Wildlife Reduction ---\n');

for lev = 1:n_levels
    wf = reduction_levels(lev);
    fprintf('  Running wildlife = %s (factor=%.1f)...\n', level_labels{lev}, wf);

    CFU_soil_sa = zeros(iterations, plantnum, 365);

    % carryover: same June-end lognormal as baseline (scale this year's wildlife only)
    for i = 1:iterations
        CFU_soil_sa(i, :, 1) = random(june_end_dist, 1);
    end

    % pre-crop
    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            daily_input = wf * (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            CFU_soil_sa(i, :, next_day_idx) = CFU_soil_sa(i, :, day_idx) + daily_input;
            CFU_soil_sa(i, :, next_day_idx) = 10.^(log10(CFU_soil_sa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    % during crop
    for i = 1:iterations
        irr_events        = irrigation_schedule_crop1{i};
        irr_day_list      = [irr_events.doy];
        source_cfu_values = irrigation_concentrations_crop1{i};

        for k = plant1(i):(har1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end

            if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
                wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                wildlife_cfu = wf * (deer_per_plant + wild_boar_per_plant) / 30;
                CFU_soil_sa(i, :, day_idx) = CFU_soil_sa(i, :, day_idx) + wildlife_cfu;
            end

            if ismember(k, irr_day_list)
                event_idx = find([irr_events.doy] == k, 1);
                stage     = irr_events(event_idx).stage;
                source_cfu_100ml  = source_cfu_values(event_idx);
                irr_depth_in      = depth_for_stage(stage, depth) * irrigation_volume_factor;
                water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
                cfu_irrig = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
                CFU_soil_sa(i, :, day_idx) = CFU_soil_sa(i, :, day_idx) + cfu_irrig;
            end

            if day_idx < 365
                CFU_soil_sa(i, :, next_day_idx) = 10.^(log10(CFU_soil_sa(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_sa(i, :, 1) = 10.^(log10(CFU_soil_sa(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end
    end

    % post-harvest
    for i = 1:iterations
        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu    = mean(CFU_soil_sa(i, :, har_day_idx));
        CFU_soil_sa(i, :, har_day_idx) = mean_cfu;
        for k = har1(i):365
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            daily_input = wf * (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            if next_day_idx > day_idx
                CFU_soil_sa(i, :, next_day_idx) = CFU_soil_sa(i, :, day_idx) + daily_input;
                CFU_soil_sa(i, :, next_day_idx) = 10.^(log10(CFU_soil_sa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
            end
        end
    end

    % daily percentiles
    CFU_daily_sa = zeros(iterations, 365);
    for i = 1:iterations
        for day = 1:365
            CFU_daily_sa(i, day) = mean(CFU_soil_sa(i, :, day));
        end
    end

    for d = 1:365
        vals = CFU_daily_sa(:, d);
        SA_wildlife_min(lev, d)    = min(vals);
        SA_wildlife_p05(lev, d)    = prctile(vals, 5);
        SA_wildlife_p25(lev, d)    = prctile(vals, 25);
        SA_wildlife_median(lev, d) = prctile(vals, 50);
        SA_wildlife_p75(lev, d)    = prctile(vals, 75);
        SA_wildlife_p95(lev, d)    = prctile(vals, 95);
        SA_wildlife_max(lev, d)    = max(vals);
    end

    % One shared soil -> onion calculation supplies both harvest summaries
    % and threshold counts for this wildlife-intensity level.
    CFU_onion_sa = soil_to_onion_harvest(CFU_soil_sa, plant1, har1, undercut1, ...
        bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
        beta_dist_onion, pert_min_onion, pert_max_onion);
    onion_sa_stats = summarize_harvest_onion(CFU_onion_sa);
    SA_wildlife_onion_mean(lev)   = onion_sa_stats.mean;
    SA_wildlife_onion_median(lev) = onion_sa_stats.median;
    SA_wildlife_onion_max(lev)    = onion_sa_stats.max;

    plants_above_wl    = zeros(iterations, n_thresh_sa);
    month_counts_wl    = zeros(12, n_thresh_sa);
    iter_per_month_wl  = zeros(12, 1);

    for i = 1:iterations
        har_day_idx    = mod(har1(i) - 1, 365) + 1;
        cfu_onion = CFU_onion_sa(i, :);

        % count plants above each threshold
        for t = 1:n_thresh_sa
            plants_above_wl(i, t) = sum(cfu_onion > thresholds_sa(t), 2);
        end

        m = get_month_index_jul_start(har_day_idx);
        if m > 12, m = 12; end
        iter_per_month_wl(m) = iter_per_month_wl(m) + 1;
        for t = 1:n_thresh_sa
            month_counts_wl(m, t) = month_counts_wl(m, t) + ...
                sum(cfu_onion > thresholds_sa(t), 2);
        end
    end

    for m = 1:12
        if iter_per_month_wl(m) > 0
            SA_wildlife_thresh_monthly(lev, m, :)       = month_counts_wl(m, :) / iter_per_month_wl(m);
            SA_wildlife_thresh_monthly_total(lev, m, :) = month_counts_wl(m, :);
            SA_wildlife_thresh_monthly_iters(lev, m)    = iter_per_month_wl(m);
        end
    end

    SA_wildlife_thresh(lev, :) = mean(plants_above_wl, 1);
    fprintf('    Threshold counts: >1=%.1f, >5=%.1f, >10=%.1f, >20=%.1f\n', ...
        SA_wildlife_thresh(lev,1), SA_wildlife_thresh(lev,2), ...
        SA_wildlife_thresh(lev,3), SA_wildlife_thresh(lev,4));

    clear CFU_onion_sa CFU_soil_sa CFU_daily_sa;
    fprintf('    Complete. Median CFU: %.2e\n', median(SA_wildlife_median(lev,:)));
end   % ← closes for lev = 1:n_levels (Analysis 1 wildlife)

% =====================================================================
%  ANALYSIS 2: IRRIGATION REDUCTION (Wildlife stays at 100%)
% =====================================================================
fprintf('\n--- Analysis 2: Irrigation Reduction ---\n');

for lev = 1:n_levels
    irf = reduction_levels(lev);
    fprintf('  Running irrigation = %s (factor=%.1f)...\n', level_labels{lev}, irf);

    CFU_soil_sa = zeros(iterations, plantnum, 365);

    % carryover: same June-end lognormal as baseline (scale this year's irrigation only)
    for i = 1:iterations
        CFU_soil_sa(i, :, 1) = random(june_end_dist, 1);
    end

    % pre-crop
    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            CFU_soil_sa(i, :, next_day_idx) = CFU_soil_sa(i, :, day_idx) + daily_input;
            CFU_soil_sa(i, :, next_day_idx) = 10.^(log10(CFU_soil_sa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    % during crop
    for i = 1:iterations
        irr_events        = irrigation_schedule_crop1{i};
        irr_day_list      = [irr_events.doy];
        source_cfu_values = irrigation_concentrations_crop1{i};

        for k = plant1(i):(har1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end

            if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
                wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                wildlife_cfu = (deer_per_plant + wild_boar_per_plant) / 30;
                CFU_soil_sa(i, :, day_idx) = CFU_soil_sa(i, :, day_idx) + wildlife_cfu;
            end

            if ismember(k, irr_day_list)
                event_idx = find([irr_events.doy] == k, 1);
                stage     = irr_events(event_idx).stage;
                source_cfu_100ml  = source_cfu_values(event_idx);
                irr_depth_in      = depth_for_stage(stage, depth) * irrigation_volume_factor;
                water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
                cfu_irrig = irf * (source_cfu_100ml / 100) * water_per_plant_L * 1000;
                CFU_soil_sa(i, :, day_idx) = CFU_soil_sa(i, :, day_idx) + cfu_irrig;
            end

            if day_idx < 365
                CFU_soil_sa(i, :, next_day_idx) = 10.^(log10(CFU_soil_sa(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_sa(i, :, 1) = 10.^(log10(CFU_soil_sa(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end
    end

    % post-harvest
    for i = 1:iterations
        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu    = mean(CFU_soil_sa(i, :, har_day_idx));
        CFU_soil_sa(i, :, har_day_idx) = mean_cfu;
        for k = har1(i):365
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            if next_day_idx > day_idx
                CFU_soil_sa(i, :, next_day_idx) = CFU_soil_sa(i, :, day_idx) + daily_input;
                CFU_soil_sa(i, :, next_day_idx) = 10.^(log10(CFU_soil_sa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
            end
        end
    end

    % daily percentiles
    CFU_daily_sa = zeros(iterations, 365);
    for i = 1:iterations
        for day = 1:365
            CFU_daily_sa(i, day) = mean(CFU_soil_sa(i, :, day));
        end
    end

    for d = 1:365
        vals = CFU_daily_sa(:, d);
        SA_irrig_min(lev, d)    = min(vals);
        SA_irrig_p05(lev, d)    = prctile(vals, 5);
        SA_irrig_p25(lev, d)    = prctile(vals, 25);
        SA_irrig_median(lev, d) = prctile(vals, 50);
        SA_irrig_p75(lev, d)    = prctile(vals, 75);
        SA_irrig_p95(lev, d)    = prctile(vals, 95);
        SA_irrig_max(lev, d)    = max(vals);
    end

    % One shared soil -> onion calculation supplies both harvest summaries
    % and threshold counts for this irrigation-intensity level.
    CFU_onion_sa = soil_to_onion_harvest(CFU_soil_sa, plant1, har1, undercut1, ...
        bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
        beta_dist_onion, pert_min_onion, pert_max_onion);
    onion_sa_stats = summarize_harvest_onion(CFU_onion_sa);
    SA_irrig_onion_mean(lev)   = onion_sa_stats.mean;
    SA_irrig_onion_median(lev) = onion_sa_stats.median;
    SA_irrig_onion_max(lev)    = onion_sa_stats.max;

    plants_above_ir   = zeros(iterations, n_thresh_sa);
    month_counts_ir   = zeros(12, n_thresh_sa);
    iter_per_month_ir = zeros(12, 1);

    for i = 1:iterations
        har_day_idx    = mod(har1(i) - 1, 365) + 1;
        cfu_onion = CFU_onion_sa(i, :);

        for t = 1:n_thresh_sa
            plants_above_ir(i, t) = sum(cfu_onion > thresholds_sa(t), 2);
        end

        m = get_month_index_jul_start(har_day_idx);
        if m > 12, m = 12; end
        iter_per_month_ir(m) = iter_per_month_ir(m) + 1;
        for t = 1:n_thresh_sa
            month_counts_ir(m, t) = month_counts_ir(m, t) + ...
                sum(cfu_onion > thresholds_sa(t), 2);
        end
    end

    for m = 1:12
        if iter_per_month_ir(m) > 0
            SA_irrig_thresh_monthly(lev, m, :)       = month_counts_ir(m, :) / iter_per_month_ir(m);
            SA_irrig_thresh_monthly_total(lev, m, :) = month_counts_ir(m, :);
            SA_irrig_thresh_monthly_iters(lev, m)    = iter_per_month_ir(m);
        end
    end

    SA_irrig_thresh(lev, :) = mean(plants_above_ir, 1);
    fprintf('    Threshold counts: >1=%.1f, >5=%.1f, >10=%.1f, >20=%.1f\n', ...
        SA_irrig_thresh(lev,1), SA_irrig_thresh(lev,2), ...
        SA_irrig_thresh(lev,3), SA_irrig_thresh(lev,4));

    clear CFU_onion_sa CFU_soil_sa CFU_daily_sa;
    fprintf('    Complete. Median CFU: %.2e\n', median(SA_irrig_median(lev,:)));
end   % closes for lev = 1:n_levels (Analysis 2 irrigation)
        
%% ========================================================================
%  VISUALIZATION — Figures 25-28 (existing) + 31-32 (threshold lines)
%% ========================================================================
month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
days   = 1:365;

sa_colors_wildlife = [0.8 0.9 0.8; 0.6 0.8 0.6; 0.4 0.7 0.4; 0.2 0.6 0.2; 0.0 0.5 0.0; ...
                      0.0 0.4 0.0; 0.0 0.3 0.0; 0.2 0.2 0.0; 0.4 0.15 0.0; 0.5 0.1 0.0];
sa_colors_irrig    = [0.8 0.85 0.95; 0.6 0.7 0.9; 0.4 0.6 0.8; 0.2 0.4 0.8; 0.0 0.3 0.8; ...
                      0.0 0.2 0.7; 0.0 0.15 0.6; 0.1 0.0 0.5; 0.2 0.0 0.4; 0.3 0.0 0.3];
sa_linewidths = [0.8, 1.0, 1.2, 1.5, 2.5, 1.5, 1.2, 1.0, 0.8, 0.8];
sa_styles     = {':', ':', '--', '--', '-', '--', '--', '-.', '-.', ':'};

% Figure 25
figure(25); clf;
for lev = 1:n_levels
    plot(days, log10(SA_wildlife_median(lev,:) + 1), sa_styles{lev}, ...
        'Color', sa_colors_wildlife(lev,:), 'LineWidth', sa_linewidths(lev), ...
        'DisplayName', sprintf('Wildlife = %s', level_labels{lev}));
    if lev == 1, hold on; end
end
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12); ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Sensitivity: Wildlife Fecal Level 20-200% (Irrigation at 100%)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1), xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off'); end
fprintf('  Figure 25 created: Wildlife sensitivity\n');

% Figure 26
figure(26); clf;
for lev = 1:n_levels
    plot(days, log10(SA_irrig_median(lev,:) + 1), sa_styles{lev}, ...
        'Color', sa_colors_irrig(lev,:), 'LineWidth', sa_linewidths(lev), ...
        'DisplayName', sprintf('Irrigation = %s', level_labels{lev}));
    if lev == 1, hold on; end
end
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12); ylabel('log_{10}(CFU per subplot + 1)', 'FontSize', 12);
title('Sensitivity: Irrigation Source Level 20-200% (Wildlife at 100%)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
for mb = month_boundaries(2:end-1), xline(mb, ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off'); end
fprintf('  Figure 26 created: Irrigation sensitivity\n');

% Figure 27
figure(27); clf;
subplot(2,1,1);
for lev = 1:n_levels
    plot(days, log10(SA_wildlife_median(lev,:) + 1), sa_styles{lev}, ...
        'Color', sa_colors_wildlife(lev,:), 'LineWidth', sa_linewidths(lev), ...
        'DisplayName', sprintf('Wildlife = %s', level_labels{lev}));
    if lev == 1, hold on; end
end
fill([days, fliplr(days)], [log10(SA_wildlife_p75(5,:)+1), fliplr(log10(SA_wildlife_p25(5,:)+1))], ...
     [0.0 0.5 0.0], 'FaceAlpha', 0.08, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;
ylabel('log_{10}(CFU+1)', 'FontSize', 11);
title('Wildlife Fecal Level 20-200% (Irrigation at 100%)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(2,1,2);
for lev = 1:n_levels
    plot(days, log10(SA_irrig_median(lev,:) + 1), sa_styles{lev}, ...
        'Color', sa_colors_irrig(lev,:), 'LineWidth', sa_linewidths(lev), ...
        'DisplayName', sprintf('Irrigation = %s', level_labels{lev}));
    if lev == 1, hold on; end
end
fill([days, fliplr(days)], [log10(SA_irrig_p75(5,:)+1), fliplr(log10(SA_irrig_p25(5,:)+1))], ...
     [0.0 0.3 0.8], 'FaceAlpha', 0.08, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold off;
xlabel('Day of Year (Jul-Jun)', 'FontSize', 12); ylabel('log_{10}(CFU+1)', 'FontSize', 11);
title('Irrigation Source Level 20-200% (Wildlife at 100%)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
sgtitle('Sensitivity Analysis: Soil E. coli per Subplot', 'FontSize', 14, 'FontWeight', 'bold');
fprintf('  Figure 27 created: Side-by-side comparison\n');

% Figure 28
figure(28); clf;
med_har_day     = round(median(mod(har1 - 1, 365) + 1));
harvest_wildlife = SA_wildlife_median(:, med_har_day);
harvest_irrig   = SA_irrig_median(:, med_har_day);

plot(reduction_levels * 100, log10(harvest_wildlife + 1), '-o', ...
    'Color', [0.0 0.5 0.0], 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', [0.0 0.5 0.0], ...
    'DisplayName', 'Wildlife Level'); hold on;
plot(reduction_levels * 100, log10(harvest_irrig + 1), '-s', ...
    'Color', [0.0 0.3 0.8], 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', [0.0 0.3 0.8], ...
    'DisplayName', 'Irrigation Level');
xline(100, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Baseline (100%)'); hold off;
xlabel('Source Level (% of Baseline)', 'FontSize', 12);
ylabel('log_{10}(Median Harvest-Day CFU + 1)', 'FontSize', 12);
title(sprintf('Harvest-Day Soil CFU vs Source Level (Day %d)', med_har_day), 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11); grid on;
set(gca, 'XTick', [20 40 60 80 100 120 140 160 180 200]); xlim([10 210]);
fprintf('  Figure 28 created: Harvest-day dose-response\n');

%% ========================================================================
%  FIGURE 31: THRESHOLD EXCEEDANCE VS SCENARIO LEVEL (line graph)
%% ========================================================================
figure(31); clf;
set(gcf, 'Position', [100 50 900 750]);

thresh_colors_sa = [0.2 0.6 0.2; 0.2 0.4 0.8; 0.9 0.5 0.0; 0.8 0.0 0.0];
x_levels = reduction_levels * 100;

subplot(2, 1, 1);
hold on;
for t = 1:n_thresh_sa
    plot(x_levels, SA_wildlife_thresh(:, t), '-o', 'Color', thresh_colors_sa(t,:), ...
        'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', thresh_colors_sa(t,:), ...
        'DisplayName', sprintf('> %d CFU', thresholds_sa(t)));
end
xline(100, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Baseline (100%)');
hold off;
xlabel('Wildlife Fecal Level (% of Baseline)', 'FontSize', 11);
ylabel('Mean Plants Exceeding Threshold', 'FontSize', 11);
title('Wildlife Intensity: Plants Exceeding CFU Thresholds at Harvest Day', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10); set(gca, 'XTick', x_levels); grid on; xlim([10 210]);
for t = 1:n_thresh_sa
    for lev = 1:n_levels
        if SA_wildlife_thresh(lev, t) > 0
            text(x_levels(lev), SA_wildlife_thresh(lev, t), sprintf('  %.0f', SA_wildlife_thresh(lev, t)), ...
                'FontSize', 7, 'Color', thresh_colors_sa(t,:));
        end
    end
end

subplot(2, 1, 2);
hold on;
for t = 1:n_thresh_sa
    plot(x_levels, SA_irrig_thresh(:, t), '-o', 'Color', thresh_colors_sa(t,:), ...
        'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', thresh_colors_sa(t,:), ...
        'DisplayName', sprintf('> %d CFU', thresholds_sa(t)));
end
xline(100, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Baseline (100%)');
hold off;
xlabel('Irrigation Source Level (% of Baseline)', 'FontSize', 11);
ylabel('Mean Plants Exceeding Threshold', 'FontSize', 11);
title('Irrigation Intensity: Plants Exceeding CFU Thresholds at Harvest Day', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10); set(gca, 'XTick', x_levels); grid on; xlim([10 210]);
for t = 1:n_thresh_sa
    for lev = 1:n_levels
        if SA_irrig_thresh(lev, t) > 0
            text(x_levels(lev), SA_irrig_thresh(lev, t), sprintf('  %.0f', SA_irrig_thresh(lev, t)), ...
                'FontSize', 7, 'Color', thresh_colors_sa(t,:));
        end
    end
end
sgtitle('Sensitivity Analysis: Mean Plants Exceeding E. coli Thresholds at Harvest Day', 'FontSize', 13, 'FontWeight', 'bold');
fprintf('  Figure 31 created: Threshold exceedance vs scenario level\n');

%% ========================================================================
%  FIGURE 32: THRESHOLD BY HARVEST MONTH — LINE GRAPH PER THRESHOLD
%% ========================================================================
months_fig32 = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

active_months_wl = squeeze(any(any(SA_wildlife_thresh_monthly > 0, 1), 3));
active_months_ir = squeeze(any(any(SA_irrig_thresh_monthly > 0, 1), 3));
active_months_32 = active_months_wl | active_months_ir;
active_labels_32 = months_fig32(active_months_32);
n_active_32      = sum(active_months_32);

figure(32); clf;
set(gcf, 'Position', [100 50 1100 850]);

display_levels = [1, 3, 5, 7, 10];
display_labels = level_labels(display_levels);
n_display      = length(display_levels);
display_styles = {':', '--', '-', '--', ':'};
display_widths = [1.0, 1.5, 2.5, 1.5, 1.0];
display_colors_wl = [0.8 0.9 0.8; 0.4 0.7 0.4; 0.0 0.5 0.0; 0.0 0.3 0.0; 0.5 0.1 0.0];
display_colors_ir = [0.8 0.85 0.95; 0.4 0.6 0.8; 0.0 0.3 0.8; 0.0 0.15 0.6; 0.3 0.0 0.3];

for t = 1:n_thresh_sa
    subplot(2, n_thresh_sa, t); hold on;
    for dl = 1:n_display
        lev = display_levels(dl);
        monthly_data = squeeze(SA_wildlife_thresh_monthly(lev, :, t));
        if n_active_32 > 0
            plot(1:n_active_32, monthly_data(active_months_32), display_styles{dl}, ...
                'Color', display_colors_wl(dl,:), 'LineWidth', display_widths(dl), ...
                'Marker', 'o', 'MarkerSize', 6, 'MarkerFaceColor', display_colors_wl(dl,:), ...
                'DisplayName', sprintf('Wildlife %s', display_labels{dl}));
        end
    end
    hold off;
    set(gca, 'XTick', 1:n_active_32, 'XTickLabel', active_labels_32);
    xlabel('Harvest Month', 'FontSize', 10); ylabel('Mean Plants', 'FontSize', 10);
    title(sprintf('Wildlife: > %d CFU', thresholds_sa(t)), 'FontSize', 11, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 7); grid on;
    if n_active_32 > 0, xlim([0.5, n_active_32 + 0.5]); end
end

for t = 1:n_thresh_sa
    subplot(2, n_thresh_sa, n_thresh_sa + t); hold on;
    for dl = 1:n_display
        lev = display_levels(dl);
        monthly_data = squeeze(SA_irrig_thresh_monthly(lev, :, t));
        if n_active_32 > 0
            plot(1:n_active_32, monthly_data(active_months_32), display_styles{dl}, ...
                'Color', display_colors_ir(dl,:), 'LineWidth', display_widths(dl), ...
                'Marker', 's', 'MarkerSize', 6, 'MarkerFaceColor', display_colors_ir(dl,:), ...
                'DisplayName', sprintf('Irrigation %s', display_labels{dl}));
        end
    end
    hold off;
    set(gca, 'XTick', 1:n_active_32, 'XTickLabel', active_labels_32);
    xlabel('Harvest Month', 'FontSize', 10); ylabel('Mean Plants', 'FontSize', 10);
    title(sprintf('Irrigation: > %d CFU', thresholds_sa(t)), 'FontSize', 11, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 7); grid on;
    if n_active_32 > 0, xlim([0.5, n_active_32 + 0.5]); end
end
sgtitle('Plants Exceeding E. coli Thresholds by Harvest Month — Key Scenario Levels', 'FontSize', 13, 'FontWeight', 'bold');
fprintf('  Figure 32 created: Threshold by harvest month per scenario level\n');

%% ========================================================================
%  FIGURES 34-53: ONE BAR CHART PER SCENARIO LEVEL (File 1 Figure 12 style)
%  Figures 34-43: Wildlife intensity 20%-200%
%  Figures 44-53: Irrigation intensity 20%-200%
%  X-axis: harvest months (Jan, Feb, Mar, Apr)
%  Y-axis: mean plants exceeding threshold + percentage subplot
%  Bars: >1, >5, >10, >20 CFU (4 grouped bars)
%% ========================================================================
fprintf('\nBuilding per-scenario bar chart figures (34-53)...\n');

months_sc = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};

% find active harvest months across all levels and both sources
active_months_sc = false(12, 1);
for lev = 1:n_levels
    for m = 1:12
        if any(squeeze(SA_wildlife_thresh_monthly(lev, m, :)) > 0) || ...
           any(squeeze(SA_irrig_thresh_monthly(lev, m, :)) > 0)
            active_months_sc(m) = true;
        end
    end
end
active_month_idx_sc   = find(active_months_sc);
active_month_names_sc = months_sc(active_months_sc);
n_active_sc           = length(active_month_idx_sc);

thresh_colors_sc = [0.2 0.6 0.2;   % >10  green
                    0.2 0.4 0.8;   % >20  blue
                    0.9 0.5 0.0;   % >50  orange
                    0.8 0.0 0.0];  % >100 red

if n_active_sc == 0
    fprintf('  WARNING: No active harvest months found for Figures 34-53.\n');
    fprintf('  Run with >= 100 iterations to see harvest month data.\n');
else

    % -----------------------------------------------------------------
    %  FIGURES 34-43: WILDLIFE INTENSITY
    % -----------------------------------------------------------------
    for lev = 1:n_levels
        fig_num = 33 + lev;  % 34 to 43
        figure(fig_num); clf;
        set(gcf, 'Position', [50 50 1000 650]);

        % build mean and percentage matrices [n_active_months x n_thresh_sa]
        bar_mean = zeros(n_active_sc, n_thresh_sa);
        bar_pct  = zeros(n_active_sc, n_thresh_sa);
        for mi = 1:n_active_sc
            m = active_month_idx_sc(mi);
            for t = 1:n_thresh_sa
                bar_mean(mi, t) = SA_wildlife_thresh_monthly(lev, m, t);
                bar_pct(mi, t)  = SA_wildlife_thresh_monthly(lev, m, t) / plantnum * 100;
            end
        end

        % --- subplot 1: mean plants ---
        subplot(2, 1, 1);
        b1 = bar(1:n_active_sc, bar_mean, 'grouped');
        for t = 1:n_thresh_sa, b1(t).FaceColor = thresh_colors_sc(t, :); end
        set(gca, 'XTick', 1:n_active_sc, 'XTickLabel', active_month_names_sc);
        xlabel('Harvest Month', 'FontSize', 12);
        ylabel('Mean Number of Plants Exceeding Threshold', 'FontSize', 12);
        title(sprintf('Wildlife = %s: Mean Plants Exceeding CFU Thresholds by Harvest Month', ...
              level_labels{lev}), 'FontSize', 12, 'FontWeight', 'bold');
        legend_labels_sc = cell(n_thresh_sa, 1);
        for t = 1:n_thresh_sa, legend_labels_sc{t} = sprintf('> %d CFU', thresholds_sa(t)); end
        legend(legend_labels_sc, 'Location', 'best', 'FontSize', 10);
        grid on; xlim([0.5, n_active_sc + 0.5]);
        for t = 1:length(b1)
            xtips = b1(t).XEndPoints; ytips = b1(t).YEndPoints;
            for k2 = 1:length(ytips)
                if ytips(k2) > 0
                    text(xtips(k2), ytips(k2), sprintf('%.0f', ytips(k2)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
                end
            end
        end

        % --- subplot 2: percentage ---
        subplot(2, 1, 2);
        b2 = bar(1:n_active_sc, bar_pct, 'grouped');
        for t = 1:n_thresh_sa, b2(t).FaceColor = thresh_colors_sc(t, :); end
        set(gca, 'XTick', 1:n_active_sc, 'XTickLabel', active_month_names_sc);
        xlabel('Harvest Month', 'FontSize', 12);
        ylabel(sprintf('%% of Total Plants (%d)', plantnum), 'FontSize', 12);
        title(sprintf('Wildlife = %s: Percentage of Plants Exceeding CFU Thresholds by Harvest Month', ...
              level_labels{lev}), 'FontSize', 12, 'FontWeight', 'bold');
        legend(legend_labels_sc, 'Location', 'best', 'FontSize', 10);
        grid on; xlim([0.5, n_active_sc + 0.5]);
        for t = 1:length(b2)
            xtips = b2(t).XEndPoints; ytips = b2(t).YEndPoints;
            for k2 = 1:length(ytips)
                if ytips(k2) > 0
                    text(xtips(k2), ytips(k2), sprintf('%.3f%%', ytips(k2)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
                end
            end
        end

        sgtitle(sprintf('Wildlife Intensity = %s — E. coli Threshold Analysis by Harvest Month', ...
                level_labels{lev}), 'FontSize', 13, 'FontWeight', 'bold');
        fprintf('  Figure %d created: Wildlife %s\n', fig_num, level_labels{lev});
    end

    % -----------------------------------------------------------------
    %  FIGURES 44-53: IRRIGATION INTENSITY
    % -----------------------------------------------------------------
    for lev = 1:n_levels
        fig_num = 43 + lev;  % 44 to 53
        figure(fig_num); clf;
        set(gcf, 'Position', [50 50 1000 650]);

        bar_mean = zeros(n_active_sc, n_thresh_sa);
        bar_pct  = zeros(n_active_sc, n_thresh_sa);
        for mi = 1:n_active_sc
            m = active_month_idx_sc(mi);
            for t = 1:n_thresh_sa
                bar_mean(mi, t) = SA_irrig_thresh_monthly(lev, m, t);
                bar_pct(mi, t)  = SA_irrig_thresh_monthly(lev, m, t) / plantnum * 100;
            end
        end

        % --- subplot 1: mean plants ---
        subplot(2, 1, 1);
        b1 = bar(1:n_active_sc, bar_mean, 'grouped');
        for t = 1:n_thresh_sa, b1(t).FaceColor = thresh_colors_sc(t, :); end
        set(gca, 'XTick', 1:n_active_sc, 'XTickLabel', active_month_names_sc);
        xlabel('Harvest Month', 'FontSize', 12);
        ylabel('Mean Number of Plants Exceeding Threshold', 'FontSize', 12);
        title(sprintf('Irrigation = %s: Mean Plants Exceeding CFU Thresholds by Harvest Month', ...
              level_labels{lev}), 'FontSize', 12, 'FontWeight', 'bold');
        legend_labels_sc2 = cell(n_thresh_sa, 1);
        for t = 1:n_thresh_sa, legend_labels_sc2{t} = sprintf('> %d CFU', thresholds_sa(t)); end
        legend(legend_labels_sc2, 'Location', 'best', 'FontSize', 10);
        grid on; xlim([0.5, n_active_sc + 0.5]);
        for t = 1:length(b1)
            xtips = b1(t).XEndPoints; ytips = b1(t).YEndPoints;
            for k2 = 1:length(ytips)
                if ytips(k2) > 0
                    text(xtips(k2), ytips(k2), sprintf('%.0f', ytips(k2)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
                end
            end
        end

        % --- subplot 2: percentage ---
        subplot(2, 1, 2);
        b2 = bar(1:n_active_sc, bar_pct, 'grouped');
        for t = 1:n_thresh_sa, b2(t).FaceColor = thresh_colors_sc(t, :); end
        set(gca, 'XTick', 1:n_active_sc, 'XTickLabel', active_month_names_sc);
        xlabel('Harvest Month', 'FontSize', 12);
        ylabel(sprintf('%% of Total Plants (%d)', plantnum), 'FontSize', 12);
        title(sprintf('Irrigation = %s: Percentage of Plants Exceeding CFU Thresholds by Harvest Month', ...
              level_labels{lev}), 'FontSize', 12, 'FontWeight', 'bold');
        legend(legend_labels_sc2, 'Location', 'best', 'FontSize', 10);
        grid on; xlim([0.5, n_active_sc + 0.5]);
        for t = 1:length(b2)
            xtips = b2(t).XEndPoints; ytips = b2(t).YEndPoints;
            for k2 = 1:length(ytips)
                if ytips(k2) > 0
                    text(xtips(k2), ytips(k2), sprintf('%.3f%%', ytips(k2)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
                end
            end
        end

        sgtitle(sprintf('Irrigation Intensity = %s — E. coli Threshold Analysis by Harvest Month', ...
                level_labels{lev}), 'FontSize', 13, 'FontWeight', 'bold');
        fprintf('  Figure %d created: Irrigation %s\n', fig_num, level_labels{lev});
    end

end  % end if n_active_sc > 0
fprintf('  Per-scenario figures complete (Figures 34-53)\n');

% Summary table
fprintf('\n--- Sensitivity Summary: Median Harvest-Day Soil CFU ---\n');
fprintf('%-12s  %15s  %15s\n', 'Level', 'Wildlife Redn', 'Irrigation Redn');
fprintf('%s\n', repmat('-', 1, 45));
for lev = 1:n_levels
    fprintf('%-12s  %15.2e  %15.2e\n', level_labels{lev}, harvest_wildlife(lev), harvest_irrig(lev));
end

fprintf('\n--- Percent Change from Baseline (100%%) ---\n');
fprintf('%-12s  %15s  %15s\n', 'Level', 'Wildlife %%chg', 'Irrigation %%chg');
fprintf('%s\n', repmat('-', 1, 45));
baseline_idx = find(reduction_levels == 1.0);
for lev = 1:n_levels
    if lev == baseline_idx, continue; end
    wl_chg = (harvest_wildlife(lev) - harvest_wildlife(baseline_idx)) / harvest_wildlife(baseline_idx) * 100;
    ir_chg = (harvest_irrig(lev) - harvest_irrig(baseline_idx)) / harvest_irrig(baseline_idx) * 100;
    fprintf('%-12s  %14.1f%%  %14.1f%%\n', level_labels{lev}, wl_chg, ir_chg);
end
fprintf('\n========== SENSITIVITY ANALYSIS COMPLETE ==========\n');

%% ========================================================================
%  SECTION 14: PREVALENCE-BASED SENSITIVITY ANALYSIS
%% ========================================================================
fprintf('\n========== PREVALENCE-BASED SENSITIVITY ANALYSIS ==========\n');

prev_levels  = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
n_prev       = length(prev_levels);
prev_labels  = {'0%', '20%', '40%', '60%', '80%', '100%'};

PA_wl_median   = zeros(n_prev, 365);
PA_ir_median   = zeros(n_prev, 365);
PA_both_median = zeros(n_prev, 365);
PA_wl_onion_mean     = zeros(n_prev, 1);
PA_wl_onion_median   = zeros(n_prev, 1);
PA_wl_onion_max      = zeros(n_prev, 1);
PA_ir_onion_mean     = zeros(n_prev, 1);
PA_ir_onion_median   = zeros(n_prev, 1);
PA_ir_onion_max      = zeros(n_prev, 1);
PA_both_onion_mean   = zeros(n_prev, 1);
PA_both_onion_median = zeros(n_prev, 1);
PA_both_onion_max    = zeros(n_prev, 1);

% threshold storage - same layout as intensity (levels x month x threshold)
PA_wl_thresh                 = zeros(n_prev, n_thresh_sa);
PA_ir_thresh                 = zeros(n_prev, n_thresh_sa);
PA_both_thresh               = zeros(n_prev, n_thresh_sa);
PA_wl_thresh_monthly         = zeros(n_prev, 12, n_thresh_sa);
PA_ir_thresh_monthly         = zeros(n_prev, 12, n_thresh_sa);
PA_both_thresh_monthly       = zeros(n_prev, 12, n_thresh_sa);
PA_wl_thresh_monthly_iters   = zeros(n_prev, 12);
PA_ir_thresh_monthly_iters   = zeros(n_prev, 12);
PA_both_thresh_monthly_iters = zeros(n_prev, 12);

% --- ANALYSIS A: WILDLIFE PREVALENCE ---
fprintf('\n--- Analysis A: Wildlife E. coli Prevalence ---\n');
for lev = 1:n_prev
    wp = prev_levels(lev);
    fprintf('  Running wildlife prevalence = %s...\n', prev_labels{lev});
    CFU_soil_pa = zeros(iterations, plantnum, 365);

    for i = 1:iterations
        CFU_soil_pa(i, :, 1) = random(june_end_dist, 1);
    end

    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if rand() < wp && is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            else
                daily_input = 0;
            end
            CFU_soil_pa(i, :, next_day_idx) = CFU_soil_pa(i, :, day_idx) + daily_input;
            CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    for i = 1:iterations
        irr_events        = irrigation_schedule_crop1{i};
        irr_day_list      = [irr_events.doy];
        source_cfu_values = irrigation_concentrations_crop1{i};
        for k = plant1(i):(har1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if rand() < wp && is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
                wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                wildlife_cfu = (deer_per_plant + wild_boar_per_plant) / 30;
                CFU_soil_pa(i, :, day_idx) = CFU_soil_pa(i, :, day_idx) + wildlife_cfu;
            end
            if ismember(k, irr_day_list)
                event_idx = find([irr_events.doy] == k, 1);
                stage     = irr_events(event_idx).stage;
                source_cfu_100ml  = source_cfu_values(event_idx);
                irr_depth_in      = depth_for_stage(stage, depth) * irrigation_volume_factor;
                water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
                cfu_irrig = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
                CFU_soil_pa(i, :, day_idx) = CFU_soil_pa(i, :, day_idx) + cfu_irrig;
            end
            if day_idx < 365
                CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_pa(i, :, 1) = 10.^(log10(CFU_soil_pa(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end
    end

    for i = 1:iterations
        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu    = mean(CFU_soil_pa(i, :, har_day_idx));
        CFU_soil_pa(i, :, har_day_idx) = mean_cfu;
        for k = har1(i):365
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if rand() < wp && is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            else
                daily_input = 0;
            end
            if next_day_idx > day_idx
                CFU_soil_pa(i, :, next_day_idx) = CFU_soil_pa(i, :, day_idx) + daily_input;
                CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
            end
        end
    end

    CFU_daily_pa = zeros(iterations, 365);
    for i = 1:iterations
        for day = 1:365, CFU_daily_pa(i, day) = mean(CFU_soil_pa(i, :, day)); end
    end
    for d = 1:365, PA_wl_median(lev, d) = prctile(CFU_daily_pa(:, d), 50); end
    onion_rng_state = rng;
    CFU_onion_pa = soil_to_onion_harvest(CFU_soil_pa, plant1, har1, undercut1, ...
        bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
        beta_dist_onion, pert_min_onion, pert_max_onion);
    rng(onion_rng_state);
    onion_pa_stats = summarize_harvest_onion(CFU_onion_pa);
    PA_wl_onion_mean(lev)   = onion_pa_stats.mean;
    PA_wl_onion_median(lev) = onion_pa_stats.median;
    PA_wl_onion_max(lev)    = onion_pa_stats.max;
    [pa_overall, pa_monthly, pa_iters] = count_harvest_thresholds(CFU_onion_pa, har1, thresholds_sa);
    PA_wl_thresh(lev, :)               = pa_overall;
    PA_wl_thresh_monthly(lev, :, :)    = pa_monthly;
    PA_wl_thresh_monthly_iters(lev, :) = pa_iters;
    fprintf('    Threshold counts: >1=%.1f, >5=%.1f, >10=%.1f, >20=%.1f\n', ...
        PA_wl_thresh(lev,1), PA_wl_thresh(lev,2), PA_wl_thresh(lev,3), PA_wl_thresh(lev,4));
    clear CFU_onion_pa CFU_soil_pa CFU_daily_pa;
    fprintf('    Complete. Median CFU: %.2e\n', median(PA_wl_median(lev,:)));
end

% --- ANALYSIS B: IRRIGATION PREVALENCE ---
fprintf('\n--- Analysis B: Irrigation E. coli Prevalence ---\n');
for lev = 1:n_prev
    ip = prev_levels(lev);
    fprintf('  Running irrigation prevalence = %s...\n', prev_labels{lev});
    CFU_soil_pa = zeros(iterations, plantnum, 365);

    for i = 1:iterations
        CFU_soil_pa(i, :, 1) = random(june_end_dist, 1);
    end

    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            CFU_soil_pa(i, :, next_day_idx) = CFU_soil_pa(i, :, day_idx) + daily_input;
            CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    for i = 1:iterations
        irr_events        = irrigation_schedule_crop1{i};
        irr_day_list      = [irr_events.doy];
        source_cfu_values = irrigation_concentrations_crop1{i};
        for k = plant1(i):(har1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
                wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                wildlife_cfu = (deer_per_plant + wild_boar_per_plant) / 30;
                CFU_soil_pa(i, :, day_idx) = CFU_soil_pa(i, :, day_idx) + wildlife_cfu;
            end
            if ismember(k, irr_day_list) && rand() < ip
                event_idx = find([irr_events.doy] == k, 1);
                stage     = irr_events(event_idx).stage;
                source_cfu_100ml  = source_cfu_values(event_idx);
                irr_depth_in      = depth_for_stage(stage, depth) * irrigation_volume_factor;
                water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
                cfu_irrig = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
                CFU_soil_pa(i, :, day_idx) = CFU_soil_pa(i, :, day_idx) + cfu_irrig;
            end
            if day_idx < 365
                CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_pa(i, :, 1) = 10.^(log10(CFU_soil_pa(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end
    end

    for i = 1:iterations
        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu    = mean(CFU_soil_pa(i, :, har_day_idx));
        CFU_soil_pa(i, :, har_day_idx) = mean_cfu;
        for k = har1(i):365
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            if ~is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = 0;
            end
            if next_day_idx > day_idx
                CFU_soil_pa(i, :, next_day_idx) = CFU_soil_pa(i, :, day_idx) + daily_input;
                CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
            end
        end
    end

    CFU_daily_pa = zeros(iterations, 365);
    for i = 1:iterations
        for day = 1:365, CFU_daily_pa(i, day) = mean(CFU_soil_pa(i, :, day)); end
    end
    for d = 1:365, PA_ir_median(lev, d) = prctile(CFU_daily_pa(:, d), 50); end
    onion_rng_state = rng;
    CFU_onion_pa = soil_to_onion_harvest(CFU_soil_pa, plant1, har1, undercut1, ...
        bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
        beta_dist_onion, pert_min_onion, pert_max_onion);
    rng(onion_rng_state);
    onion_pa_stats = summarize_harvest_onion(CFU_onion_pa);
    PA_ir_onion_mean(lev)   = onion_pa_stats.mean;
    PA_ir_onion_median(lev) = onion_pa_stats.median;
    PA_ir_onion_max(lev)    = onion_pa_stats.max;
    [pa_overall, pa_monthly, pa_iters] = count_harvest_thresholds(CFU_onion_pa, har1, thresholds_sa);
    PA_ir_thresh(lev, :)               = pa_overall;
    PA_ir_thresh_monthly(lev, :, :)    = pa_monthly;
    PA_ir_thresh_monthly_iters(lev, :) = pa_iters;
    fprintf('    Threshold counts: >1=%.1f, >5=%.1f, >10=%.1f, >20=%.1f\n', ...
        PA_ir_thresh(lev,1), PA_ir_thresh(lev,2), PA_ir_thresh(lev,3), PA_ir_thresh(lev,4));
    clear CFU_onion_pa CFU_soil_pa CFU_daily_pa;
    fprintf('    Complete. Median CFU: %.2e\n', median(PA_ir_median(lev,:)));
end

% --- ANALYSIS C: BOTH SOURCES ---
fprintf('\n--- Analysis C: Combined Prevalence (Both Sources) ---\n');
for lev = 1:n_prev
    bp = prev_levels(lev);
    fprintf('  Running both at prevalence = %s...\n', prev_labels{lev});
    CFU_soil_pa = zeros(iterations, plantnum, 365);

    for i = 1:iterations
        CFU_soil_pa(i, :, 1) = random(june_end_dist, 1);
    end

    for i = 1:iterations
        for k = 1:(plant1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if rand() < bp && is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            else
                daily_input = 0;
            end
            CFU_soil_pa(i, :, next_day_idx) = CFU_soil_pa(i, :, day_idx) + daily_input;
            CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
        end
    end

    for i = 1:iterations
        irr_events        = irrigation_schedule_crop1{i};
        irr_day_list      = [irr_events.doy];
        source_cfu_values = irrigation_concentrations_crop1{i};
        for k = plant1(i):(har1(i) - 1)
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if rand() < bp
                if is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                    deer_per_plant      = distribute_wildlife_to_subplots(CFU_deer(i, month),      plantnum, feces_deposit_locations);
                    wild_boar_per_plant = distribute_wildlife_to_subplots(CFU_wild_boar(i, month), plantnum, feces_deposit_locations);
                    wildlife_cfu = (deer_per_plant + wild_boar_per_plant) / 30;
                    CFU_soil_pa(i, :, day_idx) = CFU_soil_pa(i, :, day_idx) + wildlife_cfu;
                end
            end
            if ismember(k, irr_day_list) && rand() < bp
                event_idx = find([irr_events.doy] == k, 1);
                stage     = irr_events(event_idx).stage;
                source_cfu_100ml  = source_cfu_values(event_idx);
                irr_depth_in      = depth_for_stage(stage, depth) * irrigation_volume_factor;
                water_per_plant_L = irr_depth_in * 25.4 * area_per_plant;
                cfu_irrig = (source_cfu_100ml / 100) * water_per_plant_L * 1000;
                CFU_soil_pa(i, :, day_idx) = CFU_soil_pa(i, :, day_idx) + cfu_irrig;
            end
            if day_idx < 365
                CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, day_idx) + 1e-10) + monthly_decay(month));
            else
                CFU_soil_pa(i, :, 1) = 10.^(log10(CFU_soil_pa(i, :, 365) + 1e-10) + monthly_decay(month));
            end
        end
    end

    for i = 1:iterations
        har_day_idx = mod(har1(i) - 1, 365) + 1;
        mean_cfu    = mean(CFU_soil_pa(i, :, har_day_idx));
        CFU_soil_pa(i, :, har_day_idx) = mean_cfu;
        for k = har1(i):365
            day_idx      = mod(k - 1, 365) + 1;
            next_day_idx = mod(k, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            if month > 12, month = 12; end
            if rand() < bp && is_wildlife_intrusion_day(k, use_intrusion_schedule, intrusion_interval)
                daily_input = (CFU_deer(i, month) + CFU_wild_boar(i, month)) / (plantnum * 30);
            else
                daily_input = 0;
            end
            if next_day_idx > day_idx
                CFU_soil_pa(i, :, next_day_idx) = CFU_soil_pa(i, :, day_idx) + daily_input;
                CFU_soil_pa(i, :, next_day_idx) = 10.^(log10(CFU_soil_pa(i, :, next_day_idx) + 1e-10) + monthly_decay(month));
            end
        end
    end

    CFU_daily_pa = zeros(iterations, 365);
    for i = 1:iterations
        for day = 1:365, CFU_daily_pa(i, day) = mean(CFU_soil_pa(i, :, day)); end
    end
    for d = 1:365, PA_both_median(lev, d) = prctile(CFU_daily_pa(:, d), 50); end
    onion_rng_state = rng;
    CFU_onion_pa = soil_to_onion_harvest(CFU_soil_pa, plant1, har1, undercut1, ...
        bulb_start, soil_transfer_start, soil_transfer_interval, monthly_decay, ...
        beta_dist_onion, pert_min_onion, pert_max_onion);
    rng(onion_rng_state);
    onion_pa_stats = summarize_harvest_onion(CFU_onion_pa);
    PA_both_onion_mean(lev)   = onion_pa_stats.mean;
    PA_both_onion_median(lev) = onion_pa_stats.median;
    PA_both_onion_max(lev)    = onion_pa_stats.max;
    [pa_overall, pa_monthly, pa_iters] = count_harvest_thresholds(CFU_onion_pa, har1, thresholds_sa);
    PA_both_thresh(lev, :)               = pa_overall;
    PA_both_thresh_monthly(lev, :, :)    = pa_monthly;
    PA_both_thresh_monthly_iters(lev, :) = pa_iters;
    fprintf('    Threshold counts: >1=%.1f, >5=%.1f, >10=%.1f, >20=%.1f\n', ...
        PA_both_thresh(lev,1), PA_both_thresh(lev,2), PA_both_thresh(lev,3), PA_both_thresh(lev,4));
    clear CFU_onion_pa CFU_soil_pa CFU_daily_pa;
    fprintf('    Complete. Median CFU: %.2e\n', median(PA_both_median(lev,:)));
end

% Prevalence visualizations
month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
months = {'Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'};
days   = 1:365;

pa_colors_wl   = [0.9 0.95 0.9; 0.7 0.85 0.7; 0.4 0.7 0.4; 0.2 0.55 0.2; 0.1 0.4 0.1; 0.0 0.3 0.0];
pa_colors_ir   = [0.9 0.9 0.98; 0.7 0.75 0.9; 0.4 0.55 0.8; 0.2 0.4 0.7; 0.1 0.25 0.6; 0.0 0.15 0.5];
pa_colors_both = [0.95 0.9 0.9; 0.85 0.7 0.7; 0.7 0.45 0.45; 0.55 0.25 0.25; 0.4 0.1 0.1; 0.3 0.0 0.0];
pa_linewidths  = [0.8, 1.0, 1.2, 1.5, 2.0, 2.5];
pa_styles      = {':', ':', '--', '--', '-', '-'};

figure(29); clf;
subplot(3,1,1);
for lev = 1:n_prev
    plot(days, log10(PA_wl_median(lev,:) + 1), pa_styles{lev}, 'Color', pa_colors_wl(lev,:), ...
        'LineWidth', pa_linewidths(lev), 'DisplayName', sprintf('Wildlife prev = %s', prev_labels{lev}));
    if lev == 1, hold on; end
end
hold off; ylabel('log_{10}(CFU+1)', 'FontSize', 11);
title('A) Wildlife E. coli Prevalence (Irrigation at 100%)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(3,1,2);
for lev = 1:n_prev
    plot(days, log10(PA_ir_median(lev,:) + 1), pa_styles{lev}, 'Color', pa_colors_ir(lev,:), ...
        'LineWidth', pa_linewidths(lev), 'DisplayName', sprintf('Irrigation prev = %s', prev_labels{lev}));
    if lev == 1, hold on; end
end
hold off; ylabel('log_{10}(CFU+1)', 'FontSize', 11);
title('B) Irrigation E. coli Prevalence (Wildlife at 100%)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);

subplot(3,1,3);
for lev = 1:n_prev
    plot(days, log10(PA_both_median(lev,:) + 1), pa_styles{lev}, 'Color', pa_colors_both(lev,:), ...
        'LineWidth', pa_linewidths(lev), 'DisplayName', sprintf('Both prev = %s', prev_labels{lev}));
    if lev == 1, hold on; end
end
hold off; xlabel('Day of Year (Jul-Jun)', 'FontSize', 12); ylabel('log_{10}(CFU+1)', 'FontSize', 11);
title('C) Both Sources at Same Prevalence', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8); grid on; xlim([1 365]);
xticks(month_boundaries(1:end-1) + 15); xticklabels(months);
sgtitle('Prevalence Sensitivity: E. coli Positive Rate in Contamination Sources', 'FontSize', 14, 'FontWeight', 'bold');
fprintf('  Figure 29 created: Prevalence sensitivity 3-panel\n');

figure(30); clf;
med_har_day = round(median(mod(har1 - 1, 365) + 1));
har_wl   = PA_wl_median(:, med_har_day);
har_ir   = PA_ir_median(:, med_har_day);
har_both = PA_both_median(:, med_har_day);




% In wildlife_prevalence section:
wl_prev_data.harvestDay.median = har_wl(:)';
wl_prev_data.harvestDay.medHarvestDay = med_har_day;

% In irrigation_prevalence section:
ir_prev_data.harvestDay.median = har_ir(:)';
ir_prev_data.harvestDay.medHarvestDay = med_har_day;

% In both_prevalence section:
both_prev_data.harvestDay.median = har_both(:)';
both_prev_data.harvestDay.medHarvestDay = med_har_day;




plot(prev_levels * 100, log10(har_wl + 1), '-o', 'Color', [0.0 0.4 0.0], 'LineWidth', 2, ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.0 0.4 0.0], 'DisplayName', 'Wildlife Prevalence'); hold on;
plot(prev_levels * 100, log10(har_ir + 1), '-s', 'Color', [0.0 0.2 0.7], 'LineWidth', 2, ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.0 0.2 0.7], 'DisplayName', 'Irrigation Prevalence');
plot(prev_levels * 100, log10(har_both + 1), '-d', 'Color', [0.6 0.0 0.0], 'LineWidth', 2, ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.6 0.0 0.0], 'DisplayName', 'Both Sources');
hold off;
xlabel('E. coli Prevalence (% of Events Positive)', 'FontSize', 12);
ylabel('log_{10}(Median Harvest-Day CFU + 1)', 'FontSize', 12);
title(sprintf('Harvest-Day Soil CFU vs E. coli Prevalence (Day %d)', med_har_day), 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11); grid on;
set(gca, 'XTick', [0 20 40 60 80 100]); xlim([-5 105]);
fprintf('  Figure 30 created: Harvest-day prevalence dose-response\n');

fprintf('\n--- Prevalence Sensitivity: Median Harvest-Day Soil CFU ---\n');
fprintf('%-12s  %15s  %15s  %15s\n', 'Prevalence', 'Wildlife Only', 'Irrigation Only', 'Both Sources');
fprintf('%s\n', repmat('-', 1, 62));
for lev = 1:n_prev
    fprintf('%-12s  %15.2e  %15.2e  %15.2e\n', prev_labels{lev}, har_wl(lev), har_ir(lev), har_both(lev));
end
fprintf('\n========== PREVALENCE SENSITIVITY COMPLETE ==========\n');







% Attach harvest-day values to prevalence structs (for Fig 30 / dashboard)
wl_prev_data   = struct();
wl_prev_data.harvestDay.median       = har_wl(:)';
wl_prev_data.harvestDay.medHarvestDay = med_har_day;

ir_prev_data   = struct();
ir_prev_data.harvestDay.median       = har_ir(:)';
ir_prev_data.harvestDay.medHarvestDay = med_har_day;

both_prev_data = struct();
both_prev_data.harvestDay.median       = har_both(:)';
both_prev_data.harvestDay.medHarvestDay = med_har_day;








%% ========================================================================
%  SECTION 15: EXPORT TO JSON
%% ========================================================================
fprintf('\n========== EXPORTING TO JSON ==========\n');

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
% Keep default JSON names when blend is OFF; suffix when ON so other runs are not overwritten.
if use_pond_well_blend
    export_name_suffix = '_pond_well_50pct';
    fprintf('  Pond/well blend ON — JSON filenames use suffix "%s"\n', export_name_suffix);
else
    export_name_suffix = '';
end

month_boundaries = [0, 31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];

collapse_to_monthly = @(daily_mat) cell2mat(arrayfun(@(m) ...
    mean(daily_mat(:, (month_boundaries(m)+1):month_boundaries(m+1)), 2), ...
    1:12, 'UniformOutput', false));



% --- FILE 0: scenarios.json ---
fprintf('  Writing scenarios.json...\n');
scenarios_data = struct();
scenarios_data.irrigationOnly.daily.min = irrig_only_pct(1,:);
scenarios_data.irrigationOnly.daily.p05 = irrig_only_pct(2,:);
scenarios_data.irrigationOnly.daily.p25 = irrig_only_pct(3,:);
scenarios_data.irrigationOnly.daily.p50 = irrig_only_pct(4,:);
scenarios_data.irrigationOnly.daily.p75 = irrig_only_pct(5,:);
scenarios_data.irrigationOnly.daily.p95 = irrig_only_pct(6,:);
scenarios_data.irrigationOnly.daily.max = irrig_only_pct(7,:);
scenarios_data.irrigationOnly.harvestOnion = onion_irrig_only_stats;
scenarios_data.wildlifeOnly.daily.min = wildlife_only_pct(1,:);
scenarios_data.wildlifeOnly.daily.p05 = wildlife_only_pct(2,:);
scenarios_data.wildlifeOnly.daily.p25 = wildlife_only_pct(3,:);
scenarios_data.wildlifeOnly.daily.p50 = wildlife_only_pct(4,:);
scenarios_data.wildlifeOnly.daily.p75 = wildlife_only_pct(5,:);
scenarios_data.wildlifeOnly.daily.p95 = wildlife_only_pct(6,:);
scenarios_data.wildlifeOnly.daily.max = wildlife_only_pct(7,:);
scenarios_data.wildlifeOnly.harvestOnion = onion_wildlife_only_stats;
scenarios_data.baseline.daily.min = baseline_pct(1,:);
scenarios_data.baseline.daily.p05 = baseline_pct(2,:);
scenarios_data.baseline.daily.p25 = baseline_pct(3,:);
scenarios_data.baseline.daily.p50 = baseline_pct(4,:);
scenarios_data.baseline.daily.p75 = baseline_pct(5,:);
scenarios_data.baseline.daily.p95 = baseline_pct(6,:);
scenarios_data.baseline.daily.max = baseline_pct(7,:);
scenarios_data.baseline.harvestOnion = onion_baseline_stats;

% Species attribution (additive; wildlifeOnly remains both animals)
scenarios_data.wildlifeSpecies.irrigationIncluded = false;
scenarios_data.wildlifeSpecies.note = 'Deer-only and boar-only soil years under wildlife-only conditions (no irrigation)';
scenarios_data.wildlifeSpecies.both.daily.min = wildlife_only_pct(1,:);
scenarios_data.wildlifeSpecies.both.daily.p05 = wildlife_only_pct(2,:);
scenarios_data.wildlifeSpecies.both.daily.p25 = wildlife_only_pct(3,:);
scenarios_data.wildlifeSpecies.both.daily.p50 = wildlife_only_pct(4,:);
scenarios_data.wildlifeSpecies.both.daily.p75 = wildlife_only_pct(5,:);
scenarios_data.wildlifeSpecies.both.daily.p95 = wildlife_only_pct(6,:);
scenarios_data.wildlifeSpecies.both.daily.max = wildlife_only_pct(7,:);
scenarios_data.deerOnly.daily.min = deer_only_pct(1,:);
scenarios_data.deerOnly.daily.p05 = deer_only_pct(2,:);
scenarios_data.deerOnly.daily.p25 = deer_only_pct(3,:);
scenarios_data.deerOnly.daily.p50 = deer_only_pct(4,:);
scenarios_data.deerOnly.daily.p75 = deer_only_pct(5,:);
scenarios_data.deerOnly.daily.p95 = deer_only_pct(6,:);
scenarios_data.deerOnly.daily.max = deer_only_pct(7,:);
scenarios_data.deerOnly.harvestOnion = onion_deer_only_stats;
scenarios_data.boarOnly.daily.min = boar_only_pct(1,:);
scenarios_data.boarOnly.daily.p05 = boar_only_pct(2,:);
scenarios_data.boarOnly.daily.p25 = boar_only_pct(3,:);
scenarios_data.boarOnly.daily.p50 = boar_only_pct(4,:);
scenarios_data.boarOnly.daily.p75 = boar_only_pct(5,:);
scenarios_data.boarOnly.daily.p95 = boar_only_pct(6,:);
scenarios_data.boarOnly.daily.max = boar_only_pct(7,:);
scenarios_data.boarOnly.harvestOnion = onion_boar_only_stats;
scenarios_data.wildlifeSpecies.summary.meanBoth = mean_wl_both;
scenarios_data.wildlifeSpecies.summary.meanDeerOnly = mean_wl_deer;
scenarios_data.wildlifeSpecies.summary.meanBoarOnly = mean_wl_boar;
scenarios_data.wildlifeSpecies.summary.deerPctOfBoth = mean_wl_deer / mean_wl_both * 100;
scenarios_data.wildlifeSpecies.summary.boarPctOfBoth = mean_wl_boar / mean_wl_both * 100;
scenarios_data.harvestTiming.irrStopBeforeUndercutDays = irr_stop_before_undercut;
scenarios_data.harvestTiming.curingDays = curing_days;
scenarios_data.harvestTiming.establishmentDaysRange = [14, 28];
scenarios_data.harvestTiming.vegetativeDaysRange = [28, 35];
scenarios_data.harvestTiming.bulbDevelopmentDaysRange = [42, 56];
scenarios_data.harvestTiming.maturationDaysRange = [7, 14];
scenarios_data.harvestTiming.bulbingDaysRange = [49, 70];
scenarios_data.harvestTiming.growthDaysRange = [91, 133];
scenarios_data.harvestTiming.bulbStartDapRange = [42, 63];
scenarios_data.harvestTiming.note = ['Irrigation stops irrStopBeforeUndercutDays before undercutting; ', ...
    'curingDays is undercutting to harvest. Stage durations are independent discrete-uniform draws.'];
scenarios_data.irrigationSchedule.establishDepthIn = depth.Establish;
scenarios_data.irrigationSchedule.establishIntervalDays = ival.Establish;
scenarios_data.irrigationSchedule.vegDepthIn = depth.Veg;
scenarios_data.irrigationSchedule.vegIntervalDays = ival.Veg;
scenarios_data.irrigationSchedule.bulbDepthPertMinIn = depth.BulbMin;
scenarios_data.irrigationSchedule.bulbDepthPertModeIn = depth.BulbMode;
scenarios_data.irrigationSchedule.bulbDepthPertMaxIn = depth.BulbMax;
scenarios_data.irrigationSchedule.bulbIntervalDays = ival.Bulb;
scenarios_data.irrigationSchedule.volumeFactor = irrigation_volume_factor;
scenarios_data.irrigationSchedule.note = ['Stage irrigation depth (inches) and interval (days). ', ...
    'Establish/Veg are fixed depth; Bulb depth sampled per event from PERT(min, mode, max). ', ...
    'volumeFactor scales all stage depths (1=baseline, 0.75=25% reduction, 0.50=50% reduction, 0.25=75% reduction).'];
scenarios_data.waterQuality.meetsFda = water_meets_fda;
scenarios_data.waterQuality.gmLimit = GM_limit;
scenarios_data.waterQuality.stvLimit = STV_limit;
scenarios_data.waterQuality.gmMean = mean(irr_GM);
scenarios_data.waterQuality.gmMin = min(irr_GM);
scenarios_data.waterQuality.gmMax = max(irr_GM);
scenarios_data.waterQuality.stvMean = mean(irr_STV);
scenarios_data.waterQuality.stvMin = min(irr_STV);
scenarios_data.waterQuality.stvMax = max(irr_STV);
scenarios_data.waterQuality.note = ['Surface irrigation water: Lognormal(2.1,0.4) with 20-sample GM/STV. ', ...
    'meetsFda true = GM<=126 and STV<=410; false = GM>126 or STV>410. ', ...
    'Aligns with dashboard regulatoryStandard (fda_approved / non_fda_approved).'];
scenarios_data.wildlifeIntrusion.useSchedule = use_intrusion_schedule;
scenarios_data.wildlifeIntrusion.intervalDays = intrusion_interval;
scenarios_data.wildlifeIntrusion.fecesDepositLocations = feces_deposit_locations;
scenarios_data.wildlifeIntrusion.note = sprintf(['When useSchedule is true, each visit drops normal daily feces (monthly/30); ', ...
    'fewer visits => less total feces. Feces deposit locations = %d (total CFU conserved per pooping event).'], ...
    feces_deposit_locations);
scenarios_data.pondWellBlend.usePondWellBlend = use_pond_well_blend;
scenarios_data.pondWellBlend.wellWaterCfu100mL = well_water_cfu_100ml;
scenarios_data.pondWellBlend.pondFraction = 0.5;
scenarios_data.pondWellBlend.wellFraction = 0.5;
scenarios_data.pondWellBlend.note = ['When usePondWellBlend is true, irrigation CFU = 0.5*pond_cfu + 0.5*well. ', ...
    'pond_cfu is surface sample + rainfall. wellWaterCfu100mL is a placeholder (0) until well sampling is enabled. ', ...
    'Blend is applied when concentrations are stored, so irrigation-only and intensity scenarios inherit it.'];
n_cure_export = min(10, iterations);
scenarios_data.curingDecay.k = curing_k(1:n_cure_export)';
scenarios_data.curingDecay.mpn0 = curing_mpn0(1:n_cure_export)';
scenarios_data.curingDecay.mpn14 = curing_mpn14(1:n_cure_export)';
scenarios_data.curingDecay.irrStopDay = curing_days;
scenarios_data.curingDecay.curingDays = curing_days;
scenarios_data.curingDecay.irrStopBeforeUndercutDays = irr_stop_before_undercut;
scenarios_data.curingDecay.kMean = mean(curing_k);
scenarios_data.curingDecay.kStd = std(curing_k);
scenarios_data.curingDecay.mpn14Mean = mean(curing_mpn14);
scenarios_data.curingDecay.mpn14Std = std(curing_mpn14);
scenarios_data.curingDecay.fractionZero = sum(curing_mpn14 == 0) / iterations;
scenarios_data.curingDecay.note = ['Diagnostic only (Updated_Baseline Pathway 2). ', ...
    'mpn0 = log10(soil CFU at undercutting); mpn14 = max(0, mpn0 - k*curingDays). ', ...
    'Not applied to harvest onion CFU.'];

if use_pond_well_blend
    scenarios_out_fname = ['scenarios', export_name_suffix, '.json'];
else
    scenarios_out_fname = 'scenarios.json';
end
outpath = fullfile(export_dir, scenarios_out_fname);
fid = fopen(outpath, 'w');
if fid == -1, error('fopen failed: %s', outpath); end
fwrite(fid, jsonencode(scenarios_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);



% --- FILE 1: wildlife_intensity.json ---
fprintf('  Writing wildlife_intensity.json...\n');

wildlife_data = struct();
wildlife_data.parameter = 'wildlife_intensity';
wildlife_data.levels    = reduction_levels;
wildlife_data.labels    = level_labels;

wildlife_data.daily.min = SA_wildlife_min;
wildlife_data.daily.p05 = SA_wildlife_p05;
wildlife_data.daily.p25 = SA_wildlife_p25;
wildlife_data.daily.p50 = SA_wildlife_median;
wildlife_data.daily.p75 = SA_wildlife_p75;
wildlife_data.daily.p95 = SA_wildlife_p95;
wildlife_data.daily.max = SA_wildlife_max;

wildlife_data.monthly.min = collapse_to_monthly(SA_wildlife_min);
wildlife_data.monthly.p05 = collapse_to_monthly(SA_wildlife_p05);
wildlife_data.monthly.p25 = collapse_to_monthly(SA_wildlife_p25);
wildlife_data.monthly.p50 = collapse_to_monthly(SA_wildlife_median);
wildlife_data.monthly.p75 = collapse_to_monthly(SA_wildlife_p75);
wildlife_data.monthly.p95 = collapse_to_monthly(SA_wildlife_p95);
wildlife_data.monthly.max = collapse_to_monthly(SA_wildlife_max);

wildlife_data.harvestDay.median = harvest_wildlife(:)';
wildlife_data.harvestDay.pctChangeFromBaseline = ...
    (harvest_wildlife(:)' - harvest_wildlife(baseline_idx)) / harvest_wildlife(baseline_idx) * 100;
wildlife_data.harvestOnion.mean   = SA_wildlife_onion_mean(:)';
wildlife_data.harvestOnion.median = SA_wildlife_onion_median(:)';
wildlife_data.harvestOnion.max    = SA_wildlife_onion_max(:)';

% threshold by harvest month data
wildlife_data.thresholdByMonth.thresholds      = thresholds_sa;
wildlife_data.thresholdByMonth.months          = months_sc;
wildlife_data.thresholdByMonth.activeMonths    = active_month_names_sc;
wildlife_data.thresholdByMonth.mean            = SA_wildlife_thresh_monthly;
wildlife_data.thresholdByMonth.meanPct         = SA_wildlife_thresh_monthly / plantnum * 100;
wildlife_data.thresholdByMonth.itersPerMonth   = SA_wildlife_thresh_monthly_iters;
wildlife_data.thresholdByMonth.overallMean     = SA_wildlife_thresh;
wildlife_data.thresholdByMonth.levels          = level_labels;

outpath = fullfile(export_dir, ['wildlife_intensity', export_name_suffix, '.json']);
fid = fopen(outpath, 'w');
if fid == -1, error('fopen failed: %s', outpath); end
fwrite(fid, jsonencode(wildlife_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

% --- FILE 2: irrigation_intensity.json ---
fprintf('  Writing irrigation_intensity.json...\n');

irrigation_data = struct();
irrigation_data.parameter = 'irrigation_intensity';
irrigation_data.levels    = reduction_levels;
irrigation_data.labels    = level_labels;

irrigation_data.daily.min = SA_irrig_min;
irrigation_data.daily.p05 = SA_irrig_p05;
irrigation_data.daily.p25 = SA_irrig_p25;
irrigation_data.daily.p50 = SA_irrig_median;
irrigation_data.daily.p75 = SA_irrig_p75;
irrigation_data.daily.p95 = SA_irrig_p95;
irrigation_data.daily.max = SA_irrig_max;

irrigation_data.monthly.min = collapse_to_monthly(SA_irrig_min);
irrigation_data.monthly.p05 = collapse_to_monthly(SA_irrig_p05);
irrigation_data.monthly.p25 = collapse_to_monthly(SA_irrig_p25);
irrigation_data.monthly.p50 = collapse_to_monthly(SA_irrig_median);
irrigation_data.monthly.p75 = collapse_to_monthly(SA_irrig_p75);
irrigation_data.monthly.p95 = collapse_to_monthly(SA_irrig_p95);
irrigation_data.monthly.max = collapse_to_monthly(SA_irrig_max);

irrigation_data.harvestDay.median = harvest_irrig(:)';
irrigation_data.harvestDay.pctChangeFromBaseline = ...
    (harvest_irrig(:)' - harvest_irrig(baseline_idx)) / harvest_irrig(baseline_idx) * 100;
irrigation_data.harvestOnion.mean   = SA_irrig_onion_mean(:)';
irrigation_data.harvestOnion.median = SA_irrig_onion_median(:)';
irrigation_data.harvestOnion.max    = SA_irrig_onion_max(:)';

% threshold by harvest month data
irrigation_data.thresholdByMonth.thresholds    = thresholds_sa;
irrigation_data.thresholdByMonth.months        = months_sc;
irrigation_data.thresholdByMonth.activeMonths  = active_month_names_sc;
irrigation_data.thresholdByMonth.mean          = SA_irrig_thresh_monthly;
irrigation_data.thresholdByMonth.meanPct       = SA_irrig_thresh_monthly / plantnum * 100;
irrigation_data.thresholdByMonth.itersPerMonth = SA_irrig_thresh_monthly_iters;
irrigation_data.thresholdByMonth.overallMean   = SA_irrig_thresh;
irrigation_data.thresholdByMonth.levels        = level_labels;

outpath = fullfile(export_dir, ['irrigation_intensity', export_name_suffix, '.json']);
fid = fopen(outpath, 'w');
if fid == -1, error('fopen failed: %s', outpath); end
fwrite(fid, jsonencode(irrigation_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

% --- FILE 3: wildlife_prevalence.json ---
fprintf('  Writing wildlife_prevalence.json...\n');
wl_prev_data = struct();
wl_prev_data.parameter  = 'wildlife_prevalence';
wl_prev_data.levels     = prev_levels;
wl_prev_data.labels     = prev_labels;
wl_prev_data.daily.p50  = PA_wl_median;
wl_prev_data.monthly.p50 = collapse_to_monthly(PA_wl_median);
wl_prev_data.harvestDay.median = har_wl(:)';
wl_prev_data.harvestDay.medHarvestDay = med_har_day;
wl_prev_data.harvestOnion.mean   = PA_wl_onion_mean(:)';
wl_prev_data.harvestOnion.median = PA_wl_onion_median(:)';
wl_prev_data.harvestOnion.max    = PA_wl_onion_max(:)';
active_months_wl_prev = squeeze(any(any(PA_wl_thresh_monthly > 0, 1), 3));
wl_prev_data.thresholdByMonth.thresholds      = thresholds_sa;
wl_prev_data.thresholdByMonth.months          = months_sc;
wl_prev_data.thresholdByMonth.activeMonths    = months_sc(active_months_wl_prev);
wl_prev_data.thresholdByMonth.mean            = PA_wl_thresh_monthly;
wl_prev_data.thresholdByMonth.meanPct         = PA_wl_thresh_monthly / plantnum * 100;
wl_prev_data.thresholdByMonth.itersPerMonth   = PA_wl_thresh_monthly_iters;
wl_prev_data.thresholdByMonth.overallMean     = PA_wl_thresh;
wl_prev_data.thresholdByMonth.levels          = prev_labels;
outpath = fullfile(export_dir, ['wildlife_prevalence', export_name_suffix, '.json']);
fid = fopen(outpath, 'w');
if fid == -1, error('fopen failed: %s', outpath); end
fwrite(fid, jsonencode(wl_prev_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

% --- FILE 4: irrigation_prevalence.json ---
fprintf('  Writing irrigation_prevalence.json...\n');
ir_prev_data = struct();
ir_prev_data.parameter  = 'irrigation_prevalence';
ir_prev_data.levels     = prev_levels;
ir_prev_data.labels     = prev_labels;
ir_prev_data.daily.p50  = PA_ir_median;
ir_prev_data.monthly.p50 = collapse_to_monthly(PA_ir_median);
ir_prev_data.harvestDay.median = har_ir(:)';
ir_prev_data.harvestDay.medHarvestDay = med_har_day;
ir_prev_data.harvestOnion.mean   = PA_ir_onion_mean(:)';
ir_prev_data.harvestOnion.median = PA_ir_onion_median(:)';
ir_prev_data.harvestOnion.max    = PA_ir_onion_max(:)';
active_months_ir_prev = squeeze(any(any(PA_ir_thresh_monthly > 0, 1), 3));
ir_prev_data.thresholdByMonth.thresholds      = thresholds_sa;
ir_prev_data.thresholdByMonth.months          = months_sc;
ir_prev_data.thresholdByMonth.activeMonths    = months_sc(active_months_ir_prev);
ir_prev_data.thresholdByMonth.mean            = PA_ir_thresh_monthly;
ir_prev_data.thresholdByMonth.meanPct         = PA_ir_thresh_monthly / plantnum * 100;
ir_prev_data.thresholdByMonth.itersPerMonth   = PA_ir_thresh_monthly_iters;
ir_prev_data.thresholdByMonth.overallMean     = PA_ir_thresh;
ir_prev_data.thresholdByMonth.levels          = prev_labels;
outpath = fullfile(export_dir, ['irrigation_prevalence', export_name_suffix, '.json']);
fid = fopen(outpath, 'w');
if fid == -1, error('fopen failed: %s', outpath); end
fwrite(fid, jsonencode(ir_prev_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

% --- FILE 5: both_prevalence.json ---
fprintf('  Writing both_prevalence.json...\n');
both_prev_data = struct();
both_prev_data.parameter  = 'both_prevalence';
both_prev_data.levels     = prev_levels;
both_prev_data.labels     = prev_labels;
both_prev_data.daily.p50  = PA_both_median;
both_prev_data.monthly.p50 = collapse_to_monthly(PA_both_median);
both_prev_data.harvestDay.median = har_both(:)';
both_prev_data.harvestDay.medHarvestDay = med_har_day;
both_prev_data.harvestOnion.mean   = PA_both_onion_mean(:)';
both_prev_data.harvestOnion.median = PA_both_onion_median(:)';
both_prev_data.harvestOnion.max    = PA_both_onion_max(:)';
active_months_both_prev = squeeze(any(any(PA_both_thresh_monthly > 0, 1), 3));
both_prev_data.thresholdByMonth.thresholds      = thresholds_sa;
both_prev_data.thresholdByMonth.months          = months_sc;
both_prev_data.thresholdByMonth.activeMonths    = months_sc(active_months_both_prev);
both_prev_data.thresholdByMonth.mean            = PA_both_thresh_monthly;
both_prev_data.thresholdByMonth.meanPct         = PA_both_thresh_monthly / plantnum * 100;
both_prev_data.thresholdByMonth.itersPerMonth   = PA_both_thresh_monthly_iters;
both_prev_data.thresholdByMonth.overallMean     = PA_both_thresh;
both_prev_data.thresholdByMonth.levels          = prev_labels;
outpath = fullfile(export_dir, ['both_prevalence', export_name_suffix, '.json']);
fid = fopen(outpath, 'w');
if fid == -1, error('fopen failed: %s', outpath); end
fwrite(fid, jsonencode(both_prev_data, 'PrettyPrint', true));
fclose(fid);
fprintf('    Done: %s\n', outpath);

fprintf('\n========== JSON EXPORT COMPLETE ==========\n');
fprintf('  6 files written to: %s\n', export_dir);
fprintf('  (baseline.json is exported separately by File 1)\n');

% Paste this into MATLAB command window after File 2 runs

fprintf('\n=== JSON STRUCTURE VERIFICATION ===\n');




% Check scenarios.json structure
fprintf('\n%s fields:\n', scenarios_out_fname);
d = jsondecode(fileread(fullfile(export_dir, scenarios_out_fname)));
disp(fieldnames(d))
disp(fieldnames(d.irrigationOnly))
disp(fieldnames(d.irrigationOnly.daily))
fprintf('  irrigationOnly.daily.p50 size: %dx%d\n', size(d.irrigationOnly.daily.p50));
fprintf('  wildlifeOnly.daily.p50 size: %dx%d\n', size(d.wildlifeOnly.daily.p50));
fprintf('  baseline.daily.p50 size: %dx%d\n', size(d.baseline.daily.p50));
fprintf('  baseline.harvestOnion.median: %.4e\n', d.baseline.harvestOnion.median);
fprintf('  irrigationOnly.harvestOnion.median: %.4e\n', d.irrigationOnly.harvestOnion.median);
fprintf('  wildlifeOnly.harvestOnion.median: %.4e\n', d.wildlifeOnly.harvestOnion.median);
if isfield(d, 'pondWellBlend')
    fprintf('  pondWellBlend.usePondWellBlend: %d\n', d.pondWellBlend.usePondWellBlend);
end
if isfield(d, 'deerOnly')
    fprintf('  deerOnly.daily.p50 size: %dx%d\n', size(d.deerOnly.daily.p50));
end
if isfield(d, 'boarOnly')
    fprintf('  boarOnly.daily.p50 size: %dx%d\n', size(d.boarOnly.daily.p50));
end
if isfield(d, 'wildlifeSpecies')
    fprintf('  wildlifeSpecies.summary.deerPctOfBoth: %.1f%%\n', d.wildlifeSpecies.summary.deerPctOfBoth);
    fprintf('  wildlifeSpecies.summary.boarPctOfBoth: %.1f%%\n', d.wildlifeSpecies.summary.boarPctOfBoth);
end

% Check wildlife_intensity.json structure
fprintf('\nwildlife_intensity%s.json fields:\n', export_name_suffix);
w = jsondecode(fileread(fullfile(export_dir, ['wildlife_intensity', export_name_suffix, '.json'])));
disp(fieldnames(w))
disp(fieldnames(w.daily))
disp(fieldnames(w.thresholdByMonth))
fprintf('  daily.p50 size: %dx%d\n', size(w.daily.p50));
fprintf('  harvestDay.median size: %dx%d\n', size(w.harvestDay.median));
fprintf('  thresholdByMonth.mean size: %dx%dx%d\n', size(w.thresholdByMonth.mean));
fprintf('  thresholdByMonth.overallMean size: %dx%d\n', size(w.thresholdByMonth.overallMean));
fprintf('  thresholds: '); disp(w.thresholdByMonth.thresholds')
fprintf('  levels: '); disp(w.levels')

% Check wildlife_prevalence.json structure
fprintf('\nwildlife_prevalence%s.json fields:\n', export_name_suffix);
p = jsondecode(fileread(fullfile(export_dir, ['wildlife_prevalence', export_name_suffix, '.json'])));
disp(fieldnames(p))
fprintf('  daily.p50 size: %dx%d\n', size(p.daily.p50));
fprintf('  harvestDay.median size: %dx%d\n', size(p.harvestDay.median));
fprintf('  harvestDay.medHarvestDay: %d\n', p.harvestDay.medHarvestDay);
disp(fieldnames(p.thresholdByMonth))
fprintf('  thresholdByMonth.mean size: %dx%dx%d\n', size(p.thresholdByMonth.mean));
fprintf('  thresholdByMonth.overallMean size: %dx%d\n', size(p.thresholdByMonth.overallMean));
fprintf('  thresholdByMonth.meanPct size: %dx%dx%d\n', size(p.thresholdByMonth.meanPct));

fprintf('\n=== VERIFICATION COMPLETE ===\n');

%% ========================================================================
%  SECTION 16: SAVE ALL FIGURES AS .FIG AND .PNG
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
    15,  'curing_decay_fits'; ...
    19,  'wildlife_species_attribution'; ...
    21,  'scenario_irrigation_only'; ...
    22,  'scenario_wildlife_only'; ...
    23,  'scenario_median_comparison'; ...
    24,  'scenario_3panel'; ...
    25,  'sensitivity_wildlife_median'; ...
    26,  'sensitivity_irrigation_median'; ...
    27,  'sensitivity_sidebyside'; ...
    28,  'sensitivity_harvest_day'; ...
    29,  'prevalence_3panel'; ...
    30,  'prevalence_harvest_day'; ...
    31,  'threshold_vs_scenario_level'; ...
    32,  'threshold_by_month_linegraph'; ...
};

for lev = 1:n_levels
    fig_list{end+1, 1} = 33 + lev;
    fig_list{end,   2} = sprintf('wildlife_%s_threshold_by_month', ...
                                  strrep(level_labels{lev}, '%', 'pct'));
end
for lev = 1:n_levels
    fig_list{end+1, 1} = 43 + lev;
    fig_list{end,   2} = sprintf('irrigation_%s_threshold_by_month', ...
                                  strrep(level_labels{lev}, '%', 'pct'));
end

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

function CFU_onion_harvest = soil_to_onion_harvest(CFU_soil_input, plant_days, harvest_days, ...
        undercut_days, bulb_start_dap, transfer_start_mode, transfer_interval, ...
        decay_by_month, beta_distribution, transfer_min, transfer_max)
    % Apply one consistent soil -> onion calculation to any scenario soil cube.
    % The result is [iterations x plants] final onion-surface CFU at harvest.
    % This intentionally preserves the existing model behavior: transfer occurs
    % from the configured start through the day before harvest, and accumulated
    % onion CFU receives the month-specific decay after each transfer day.
    [n_iterations, n_plants, n_days] = size(CFU_soil_input);
    if n_days ~= 365
        error('CFU_soil_input must have 365 daily slices; received %d.', n_days);
    end
    if numel(plant_days) ~= n_iterations || numel(harvest_days) ~= n_iterations || ...
            numel(undercut_days) ~= n_iterations || numel(bulb_start_dap) ~= n_iterations
        error('Timing vectors must contain one value per soil iteration.');
    end

    CFU_onion_harvest = zeros(n_iterations, n_plants, 'like', CFU_soil_input);
    for i = 1:n_iterations
        transfer_start_i = soil_transfer_start_day(plant_days(i), bulb_start_dap(i), ...
            undercut_days(i), transfer_start_mode);
        cfu_onion = zeros(1, n_plants, 'like', CFU_soil_input);

        for transfer_day = transfer_start_i:transfer_interval:(harvest_days(i) - 1)
            day_idx = mod(transfer_day - 1, 365) + 1;
            month = get_month_index_jul_start(day_idx);
            transfer_coefficient = transfer_min + (transfer_max - transfer_min) * ...
                random(beta_distribution, 1, n_plants);
            soil_this_day = reshape(CFU_soil_input(i, :, day_idx), 1, n_plants);
            cfu_onion = cfu_onion + transfer_coefficient .* soil_this_day;
            cfu_onion = 10.^(log10(cfu_onion + 1e-10) + decay_by_month(month));
        end

        CFU_onion_harvest(i, :) = cfu_onion;
    end
end

function [overall_mean, monthly_mean, monthly_iters] = count_harvest_thresholds(CFU_onion, harvest_days, thresholds)
    n_iter = size(CFU_onion, 1);
    n_th   = numel(thresholds);
    plants_above  = zeros(n_iter, n_th);
    month_counts  = zeros(12, n_th);
    monthly_iters = zeros(1, 12);
    monthly_mean  = zeros(1, 12, n_th);

    for i = 1:n_iter
        har_day_idx = mod(harvest_days(i) - 1, 365) + 1;
        cfu_onion   = CFU_onion(i, :);
        for t = 1:n_th
            plants_above(i, t) = sum(cfu_onion > thresholds(t), 2);
        end
        m = get_month_index_jul_start(har_day_idx);
        if m > 12, m = 12; end
        monthly_iters(m) = monthly_iters(m) + 1;
        for t = 1:n_th
            month_counts(m, t) = month_counts(m, t) + sum(cfu_onion > thresholds(t), 2);
        end
    end

    for m = 1:12
        if monthly_iters(m) > 0
            monthly_mean(1, m, :) = month_counts(m, :) / monthly_iters(m);
        end
    end
    overall_mean = mean(plants_above, 1);
end

function stats = summarize_harvest_onion(CFU_onion_harvest)
    % Compact summaries allow each large scenario matrix to be released
    % immediately after it has been used.
    values = CFU_onion_harvest(:);
    stats.mean = mean(values);
    stats.median = median(values);
    stats.std = std(values);
    stats.min = min(values);
    stats.max = max(values);
    stats.iterationMeanMedian = median(mean(CFU_onion_harvest, 2));
end

function pond_cfu = calculate_pond_concentration(source_cfu_100ml, wildlife_runoff_cfu, pond_volume_L)
    source_total_cfu = source_cfu_100ml * (pond_volume_L / 100);
    total_cfu = source_total_cfu + wildlife_runoff_cfu;
    pond_cfu  = total_cfu / (pond_volume_L / 100);
end

function cw = sample_IrrigationSource1(n)
    pd = makedist('Lognormal', 2.1, 0.4);
    cw = random(pd, n, 1);
end

function cw = sample_IrrigationSource2(n)
    a_min   = 0.0011;
    mu_dist = makedist('Triangular', 'a', 3.5, 'b', 119.985, 'c', 236.47);
    mu      = random(mu_dist, n, 1);
    b_dist  = makedist('Triangular', 'a', 9.47, 'b', 1505.235, 'c', 3001.0);
    b_max   = random(b_dist, n, 1);
    mode    = 3*mu - (a_min + b_max);
    mode    = min(max(mode, a_min + 1e-9), b_max - 1e-9);
    td      = makedist('Triangular', 'a', a_min, 'b', mode, 'c', b_max);
    cw      = random(td, n, 1);
end

function cfu_gain = calculate_rainfall_cfu_gain(rainfall_mm)
    R         = rainfall_mm;
    delta_E   = 0.0824 * R - 0.0011 * R^2;
    cfu_gain  = max(0, delta_E);
end

function k_start = soil_transfer_start_day(plant_day, bulb_start_dap, undercut_day, soil_transfer_start)
    bulbing_day = plant_day + bulb_start_dap;
    if strcmp(soil_transfer_start, 'bulbing')
        k_start = bulbing_day;
    elseif strcmp(soil_transfer_start, 'undercut')
        k_start = undercut_day;
    else
        error('soil_transfer_start must be ''bulbing'' or ''undercut''');
    end
end

function irr_schedule = onion_irrig_days(plantDay, undercutDay, establishmentDays, bulbStart, irr_stop_before_undercut, ival)
    % build irrigation schedule from growth stages; stop before undercutting
    irr_schedule = struct('doy', {}, 'stage', {});
    k   = plantDay;
    idx = 0;
    undercut_dap = undercutDay - plantDay;
    while k < undercutDay
        dap   = k - plantDay;
        if dap < establishmentDays
            iv    = ival.Establish;
            stage = 'Establish';
        elseif dap < bulbStart
            iv    = ival.Veg;
            stage = 'Veg';
        elseif dap < (undercut_dap - irr_stop_before_undercut)
            iv    = ival.Bulb;
            stage = 'Bulb';
        else
            break;
        end
        idx = idx + 1;
        irr_schedule(idx).doy   = k;
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
    % Return a row so it always matches CFU_soil(i, :, day) slices.
    subplot_cfu = zeros(1, num_subplots);
    n = min(num_locations, num_subplots);
    affected_plants = randperm(num_subplots, n);
    subplot_cfu(affected_plants) = CFU_total / n;
end

function trans = transferfn(val)
    if val <= 0.619
        trans = 1.3 * (val - 0) / (0.619 - 0);
    elseif val >= 0.619 && val <= 0.946
        trans = 1.3 + ((340 - 1.3) * (val - 0.619) / (0.946 - 0.619));
    else
        trans = 340 + ((230000 - 340) * (val - 0.946) / (1 - 0.946));
    end
end

function month = get_month_index_jul_start(day_of_year)
    month_days = [31, 62, 92, 123, 153, 184, 215, 243, 274, 304, 335, 365];
    day_idx    = mod(day_of_year - 1, 365) + 1;
    month      = find(day_idx <= month_days, 1, 'first');
    if isempty(month), month = 12; end
end


