function [ new_state, prob ] = sineha_transition( model, state, new_state )
%ha_transition Sample and/or evaluate observation density for the heartbeat
%alignment model.

% prob is a log-probability.

A = state(1);
T = state(2);
tau = state(3);
omega = state(4);
phi = state(5);
B = state(6);

% Sample state if not provided
if (nargin<3)||isempty(new_state)
    new_A = model.A_shift + gamrnd(model.A_shape, model.A_scale);
    new_T = lognrnd(log(T)-model.T_vol/2, sqrt(model.T_vol));
%     new_tau = new_T + gamrnd(model.tau_shape, model.tau_scale);
    new_tau = gamrnd(model.tau_shape, model.tau_scale);
    new_omega = mvnrnd(omega, model.omega_vr);
    new_phi = mvnrnd(phi, model.phi_vr);
    new_B = mvnrnd(B, model.B_vr);

    new_state = [new_A; new_T; new_tau; new_omega; new_phi; new_B];
else
    new_A = new_state(1);
    new_T = new_state(2);
    new_tau = new_state(3);
    new_omega = new_state(4);
    new_phi = new_state(5);
    new_B = new_state(6);
end

% Calculate probability if required
if nargout>1
    if new_tau-new_T > 0
        prob = 0;
        prob = prob + log(gampdf(new_A-model.A_shift, model.A_shape, model.A_scale));
        prob = prob + log(lognpdf(new_T, log(T)-model.T_vol/2, sqrt(model.T_vol)));
%         prob = prob + log(gampdf(new_tau-new_T, model.tau_shape, model.tau_scale));
        prob = prob + log(gampdf(new_tau, model.tau_shape, model.tau_scale));
        prob = prob + loggausspdf(new_omega, omega, model.omega_vr);
        prob = prob + loggausspdf(new_phi, phi, model.phi_vr);
        prob = prob + loggausspdf(new_B, B, model.B_vr);
    else
        prob = -Inf;
    end
else
    prob = [];
end

end

