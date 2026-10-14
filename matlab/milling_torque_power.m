clc;
clearvars;
close all;

% Define constants and parameters
ToolRadius = 19.05 / 2;   % Tool radius in mm
N = 4;                    % Number of teeth
HelixAngle = 30;          % Helix angle in degrees
RakeAngle = 12;           % Rake angle in degrees
doc = 5.08;               % Axial depth of cut in mm
woc = 19.05/2;            % Radial width of cut in mm
f = 0.05;                 % Feed per tooth in mm
Vc = 30;                  % Cutting speed in m/min
PitchAngle = 360 / N;     % Pitch angle in degrees
tau = 613;                % Shear stress in MPa
betan = 19.1 + 0.29 * RakeAngle; % Friction angle in degrees


% Edge force coefficients (assumed constant)
Kte = 24;
Kre = 43;
Kae = 0;

condition = 0;

% Set start and exit angles based on the milling condition
if condition == 1
    % Down-milling
    phi_st = 180 - rad2deg(acos(1 - woc / ToolRadius)); % Start angle for down-milling
    phi_ex = 180; % Exit angle for down-milling
else
    % Up-milling
    phi_st = 0; % Start angle for up-milling
    phi_ex = rad2deg(acos(1 - woc / ToolRadius)); % Exit angle for up-milling
end

% Discretization parameters
s_n = round(doc / 0.001); % Number of vertical elements
S_dz = doc / s_n;         % Thickness of each element
S_nphi = 360;             % Number of angular increments
S_dphi = 360 / S_nphi;    % Angular increment size

% Initialize arrays
phi = linspace(0, 360, S_nphi);
Ft = zeros(1, S_nphi);
Fr = zeros(1, S_nphi);
Fa = zeros(1, S_nphi);
Fx = zeros(1, S_nphi);
Fy = zeros(1, S_nphi);
Fz = zeros(1, S_nphi);
Fxy = zeros(1, S_nphi);

% Main computation loop
for i = 1:S_nphi
    for k = 1:N
        phi_tip = mod(phi(i) + (k - 1) * PitchAngle, 360);
        lag = 2 * tand(HelixAngle) / (2 * ToolRadius); % Lag angle

        for j = 1:s_n
            z_dis = j * S_dz;                                      % Height of distributed chip
            phiz = mod(phi_tip - rad2deg(lag * z_dis), 360);       % Immersion angle for tooth j at height z_dis (rotation angle)


            if (phi_st <= phiz && phiz <= phi_ex) || (condition == 1 && phi_st > phi_ex && (phiz >= phi_st || phiz <= phi_ex))
                h = f * sind(phiz);
                
                % Orthogonal data calculation
                r = (1.755 - 0.028 * RakeAngle) * h^(0.331 - 0.0082 * RakeAngle);   % Chip ratio
                shearn = atan2d(r * cosd(RakeAngle), 1 - r * sind(RakeAngle));      % Shear angle in degrees
                
                % Oblique transformation
                C = sqrt((cosd(shearn + betan - RakeAngle))^2 + tand(HelixAngle)^2 * (sind(betan))^2);
                Krc = tau / sind(shearn) / cosd(HelixAngle) * sind(betan - RakeAngle) / C;
                Ktc = tau / sind(shearn) * (cosd(betan - RakeAngle) + tand(HelixAngle)^2 * sind(betan)) / C;
                Kac = tau / sind(shearn) * (cosd(betan - RakeAngle) * tand(HelixAngle) - tand(HelixAngle) * sind(betan)) / C;

                Krc2(i)=Krc;
                Ktc2(i)=Ktc;
                Kac2(i)=Kac;
                h2(i)=h;
                % Differential forces calculation
                dFt = S_dz * (Ktc * h + Kte);
                dFr = S_dz * (Krc * h + Kre);
                dFa = S_dz * (Kac * h + Kae);

                % Milling force transformations
                dFx = -dFt * cosd(phiz) - dFr * sind(phiz);
                dFy = dFt * sind(phiz) - dFr * cosd(phiz);
                dFz = -dFa;
                dFxy = ((dFx.^2 + dFy.^2).^0.5);

                % Integration of global cutting forces
                Ft(i) = Ft(i) + dFt;
                Fr(i) = Fr(i) + dFr;
                Fa(i) = Fa(i) + dFa;
                Fx(i) = Fx(i) + dFx;
                Fy(i) = Fy(i) + dFy;
                Fz(i) = Fz(i) + dFz;                
                Fxy(i) = Fxy(i) + dFxy;
            end
            
        end
        
    end
    
end


% Post-processing for results
% Fxy=(Fx.^2+Fy.^2).^0.5;
T = Ft .* (ToolRadius / 1000);
Power = (Ft .* (Vc / 60)) ./ 1000;

% Calculate max and mean forces
Fxmax = max(Fx);
Fymax = max(Fy);
Fzmax = max(Fz);
Tmax = max(T);
Pmax = max(Power);
Fxavg = mean(Fx);
Fyavg = mean(Fy);
Fzavg = mean(Fz);
Tavg = mean(T);
Pavg = mean(Power);

% Plotting results with max and mean values annotated
figure;
plot(phi, Fx, 'r'); hold on;
plot(phi, Fy, 'b'); hold on;
plot(phi, Fz, 'k'); hold off;
xlabel('Rotation angle (\phi)'), ylabel('Force (N)'), title('Cutting Forces'), legend('Fx', 'Fy', 'Fz');
grid on

figure;
plot(phi, Fxy, 'k');
xlabel('Rotation angle (\phi)'), ylabel('Force (N)'), title('Force on X-Y plane');
grid on

figure;
plot(phi, T, 'k');
xlabel('Rotation angle (\phi)'), ylabel('Torque (Nm)'), title('Torque');
grid on

figure;
plot(phi, Power, 'k');
xlabel('Rotation angle (\phi)'), ylabel('Power (KW)'), title('Cutting Power');
grid on