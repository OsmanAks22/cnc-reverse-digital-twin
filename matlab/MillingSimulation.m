clc;
clearvars;
close all;

% Define the tool and material properties
ToolRadius = 12 / 2;     % Tool radius in mm
N = 4;                   % Number of teeth
HelixAngle = 30;         % Helix angle in degrees
RakeAngle = 12;          % Rake angle in degrees
Vc = 30;                 % Cutting speed in m/min
PitchAngle = 360 / N;    % Pitch angle in degrees
tau = 613;               % Shear stress in MPa
betan = 19.1 + 0.29 * RakeAngle; % Friction angle in degrees

Kte = 24;  % Tangential edge force coefficient (N/mm)
Kre = 43;  % Radial edge force coefficient (N/mm)
Kae = 0;   % Axial edge force coefficient (N/mm)

% Parameter grid (defined first so the result matrix can be preallocated)
axial_depth_range = [2 5 6 10 11 15];  % Axial depth of cut (mm)
radial_width_range = [1 4 7 10 12];    % Radial width of cut (mm)
feed_range = [.02 .05 .08 .1 .12 .15]; % Feed per tooth (mm)
milling_conditions = [0 1];            % 0 = up-milling, 1 = down-milling

% Preallocate result storage: one row per parameter combination and angular step
S_nphi = 360;
results = zeros(numel(milling_conditions) * numel(axial_depth_range) * ...
    numel(radial_width_range) * numel(feed_range) * S_nphi, 8);
row = 0;

% Loop over all combinations of parameters
for condition = milling_conditions
    for doc = axial_depth_range
        for woc = radial_width_range
            for f = feed_range
                % Discretization parameters
                s_n = round(doc / 0.001); % Number of vertical elements
                S_dz = doc / s_n;        % Thickness of each element
                S_nphi = 360;           % Number of angular increments
                phi = linspace(0, 360, S_nphi);
                
                % Initialize arrays for forces
                Fx = zeros(1, S_nphi);
                Fy = zeros(1, S_nphi);
                Fz = zeros(1, S_nphi);

                % Set start and exit angles based on milling condition
                if condition == 1
                    % Down-milling
                    phi_st = 180 - rad2deg(acos(1 - woc / ToolRadius)); % Start angle
                    phi_ex = 180; % Exit angle
                else
                    % Up-milling
                    phi_st = 0; % Start angle
                    phi_ex = rad2deg(acos(1 - woc / ToolRadius)); % Exit angle
                end

                % Main computation loop
                for i = 1:S_nphi
                    for k = 1:N
                        phi_tip = mod(phi(i) + (k - 1) * PitchAngle, 360);
                        lag = 2 * tand(HelixAngle) / (2 * ToolRadius); % Lag angle

                        for j = 1:s_n
                            z_dis = j * S_dz;                                      % Height of distributed chip
                            phiz = mod(phi_tip - rad2deg(lag * z_dis), 360);       % Immersion angle for tooth j at height z_dis

                            if (phi_st <= phiz && phiz <= phi_ex) || (condition == 1 && phi_st > phi_ex && (phiz >= phi_st || phiz <= phi_ex))
                                h = f * sind(phiz);

                                % Orthogonal data calculation
                                r = (1.755 - 0.028 * RakeAngle) * h^(0.331 - 0.0082 * RakeAngle); % Chip ratio
                                shearn = atan2d(r * cosd(RakeAngle), 1 - r * sind(RakeAngle));    % Shear angle in degrees

                                % Oblique transformation
                                C = sqrt((cosd(shearn + betan - RakeAngle))^2 + tand(HelixAngle)^2 * (sind(betan))^2);
                                Krc = tau / sind(shearn) / cosd(HelixAngle) * sind(betan - RakeAngle) / C;
                                Ktc = tau / sind(shearn) * (cosd(betan - RakeAngle) + tand(HelixAngle)^2 * sind(betan)) / C;
                                Kac = tau / sind(shearn) * (cosd(betan - RakeAngle) * tand(HelixAngle) - tand(HelixAngle) * sind(betan)) / C;

                                % Differential forces calculation
                                dFt = S_dz * (Ktc * h + Kte);
                                dFr = S_dz * (Krc * h + Kre);
                                dFa = S_dz * (Kac * h + Kae);

                                % Milling force transformations
                                dFx = -dFt * cosd(phiz) - dFr * sind(phiz);
                                dFy = dFt * sind(phiz) - dFr * cosd(phiz);
                                dFz = -dFa;

                                % Summing up forces for the current angular position
                                Fx(i) = Fx(i) + dFx;
                                Fy(i) = Fy(i) + dFy;
                                Fz(i) = Fz(i) + dFz;
                                
                            end
                        end
                    end
                    row = row + 1;
                    results(row, :) = [condition, doc, woc, f, i, Fx(i), Fy(i), Fz(i)];
                end
                

            end
        end
    end
end

% Convert results to cell array and add header
header = {'Milling Condition', 'Axial Depth of Cut (mm)', 'Radial Width of Cut (mm)', 'Feed (mm)', 'Immersion Angle (degree)', 'Fx', 'Fy', 'Fz'};
output = [header; num2cell(results)];

% Write results to an Excel file
filename = 'MillingSimulationResults2.xlsx';
writecell(output, filename);

disp(['Simulation completed. Results have been saved to ', filename]);
