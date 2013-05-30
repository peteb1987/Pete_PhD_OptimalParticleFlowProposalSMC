function [ state, ppsl_prob ] = nlng_smoothupdatebyparticle( display, algo, model, fh, prev_state, obs )
%nlng_smoothupdatebyparticle Apply a smooth update for the nonlinear non-Gaussian
%benchmark model for a single particle (which means no intermediate
%resampling, but step size control is easier.)

dl_start = 1E-3;
dl_min = 1E-5;
dl_max = 0.5;
err_thresh = 0.001;
dl_sf = 0.8;
dl_pow = 0.7;

% Prior
if isempty(prev_state)
    m = model.m1;
    P = model.P1;
else
    prev_kk = prev_state(1);
    prev_x = prev_state(2:end);
    m = nlng_f(model, prev_kk, prev_x);
    P = model.Q;
end

% Sample initial state
if ~isempty(prev_state)
    [init_state, init_trans_prob] = feval(fh.transition, model, prev_state);
else
    [init_state, init_trans_prob] = feval(fh.stateprior, model);
end

% Initialise evolution arrays
dl_evo = dl_start;
lam_evo = 0;
err_evo = 0;
state_evo = init_state;
post_prob_evo = init_trans_prob;
ppsl_prob_evo = init_trans_prob;

% Initialise loop variables
state = init_state;
post_prob = init_trans_prob;
ppsl_prob = init_trans_prob;
dl = dl_start;
lam = 0;

% Loop
while lam < 1
    
    % Pseudo-time and step-size
    lam0 = lam;
    lam1 = lam + dl;
    if lam1 > 1
        lam1 = 1;
    end
    
    % Starting point
    x0 = state(2:end);
    kk = state(1);
    
    % Observation mean
    obs_mn = nlng_h(model, x0);
    
    % Linearise observation model around the current point
    H = nlng_obsjacobian(model, x0);
    y = obs - obs_mn + H*x0;
    
    % SMoN scaling.
    if ~isinf(model.dfy)
        xi = chi2rnd(model.dfy);
    else
        xi = 1;
    end
    R = model.R / xi;
    
    % Analytical flow
    [ x, wt_jac, prob_ratio, drift] = linear_flow_move( lam1, lam0, x0, m, P, y, H, R, algo.Dscale );
    
    % Error estimate
    H_new = nlng_obsjacobian(model, x);
    y_new = obs - nlng_h(model, x) + H_new*x;
    drift_new = linear_drift( lam1, x, m, P, y_new, H_new, R, algo.Dscale );
    err_est = 0.5*dl*( drift_new - drift );
    
    % Step size adjustment
    err_crit = norm(err_est, 2);
    dl = min(dl_max, min(10*dl, dl_sf * (err_thresh/err_crit)^dl_pow * dl));
    if dl < dl_min
        dl = dl_min;
        warning('nlng_smoothupdatebyparticle:ErrorTolerance', 'Minimum step size reached. Local error tolerance exceeded.');
    end
    
    % Accept/reject step
    if err_crit < err_thresh
        
        % Update time
        lam = lam1;
        
        % Update state
        state = [kk; x];
        
        % Densities
        if ~isempty(prev_state)
            [~, trans_prob] = feval(fh.transition, model, prev_state, state);
        else
            [~, trans_prob] = feval(fh.stateprior, model, state);
        end
        [~, lhood_prob] = feval(fh.observation, model, state, obs);
        
        % Update probabilities
        post_prob = trans_prob + lam*lhood_prob;
        if algo.Dscale == 0
            ppsl_prob = ppsl_prob - log(wt_jac);
        else
            ppsl_prob = ppsl_prob - log(prob_ratio);
        end
        
        % Update evolution
        dl_evo = [dl_evo dl];
        lam_evo = [lam_evo lam];
        err_evo = [err_evo err_crit];
        state_evo = [state_evo state];
        post_prob_evo = [post_prob_evo post_prob];
        ppsl_prob_evo = [ppsl_prob_evo ppsl_prob];
        
    else
        
%         disp('Error too large. Reducing step size');
        
    end
    
end

% Plotting
if display.plot_particle_paths
    
    % 2D state trajectories
    figure(display.h_ppp(1));
    plot(state_evo(2,:), state_evo(3,:));
    plot(init_state(2), init_state(3), 'o');
    plot(state(2), state(3), 'xr');
    
    % 1D state trajectories
    figure(display.h_ppp(2));
    plot(lam_evo, state_evo(3,:));
    
    % Step size
    figure(display.h_ppp(3));
    plot(lam_evo, dl_evo);
    
    % Error estimates
    figure(display.h_ppp(4));
    plot(lam_evo, err_evo);
    
    % Probability estimate
    figure(display.h_ppp(5));
    plot(lam_evo, post_prob_evo-ppsl_prob_evo);
    
end

end
