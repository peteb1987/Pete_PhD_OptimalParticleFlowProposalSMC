function [state, ppsl_prob] = nlng_linearisedoidproposal( model, prev_state, obs, state )
%nlng_linearisedoidproposal Sample and/or evaluate approximation of the OID
%for linearised around a local maximum for the nonlinear non-Gaussian
%benchmark model.

% If prev_state is empty, assume that this is the first step, so use the
% prior density instead of the transition density.

% Unpack the state
if ~isempty(prev_state)
    prev_kk = prev_state(1);
    prev_x = prev_state(2:end);
else
    prev_kk = 0;
end

% Prior
if isempty(prev_state)
    prior_mn = model.m1;
    prior_vr = model.P1;
else
    prior_mn = nlng_f(model, prev_kk, prev_x);
    prior_vr = model.Q;
end

% % Sample a mixing value and scale the covariance
% if ~isinf(model.dfy)
%     xi = chi2rnd(model.dfy);
% else
%     xi = 1;
% end
% R = model.R / xi;

% Maximise OID
h_of = @(x) log_oid_with_derivs(model, prior_mn, prior_vr, obs, x);
options = optimset('GradObj','on','Hessian','on','Display','notify-detailed');
options = optimset('GradObj','on','Display','notify-detailed');
start_x = prior_mn+2*rand(model.ds-1,1)-1;
lin_x = fminunc(h_of,start_x,options);

% Laplace Approximation
[~, ~, Hess] = log_oid_with_derivs(model, prior_mn, prior_vr, obs, lin_x);
ppsl_mn = lin_x;
ppsl_vr = inv(Hess);
assert(isposdef(ppsl_vr));

% Sample state if not provided
if (nargin<4)||isempty(state)
    kk = prev_kk + 1;
    x = mvnrnd(ppsl_mn', ppsl_vr)';
    state = [kk; x];
else
    kk = state(1);
    x = state(2:end);
    assert(kk==prev_kk+1);
end

% Calculate probability if required
if nargout>1
    ppsl_prob = loggausspdf(x, ppsl_mn, ppsl_vr);
else
    ppsl_prob = [];
end

end

function [func, grad, Hess] = log_oid_with_derivs(model, m, Q, y, x)
% Negative Log-OID with gradient and Hessian

R = model.R;
dfy = model.dfy;
do = model.do;
h_x = nlng_h(model, x);
H = nlng_obsjacobian(model, x);
dy = y - h_x;
dx = x - m;
yR = (R\dy);
tdist = 1 + dy'*yR/dfy;

if isinf(dfy)
    func = ( yR'*dy + (dx'/Q)*dx )/2;
    grad = - H'*yR + Q\dx;
else
    func = (dx'/Q)*dx/2 + (dfy+do)*log(tdist)/2;
    grad = Q\dx - (dfy+do)*(H*yR)/(dfy*tdist);
end

if nargout > 2
    
    prior_hess = inv(Q);
    
    ds = model.ds-1;
    nl = model.alpha1 * model.alpha2 * (model.alpha2-1) * (x.^2).^(model.alpha2/2 - 1);
    nl(isnan(nl)) = 0;
    at = zeros(ds);         % The awkward term
    for ii = 1:model.do
        at(2*ii-1,2*ii-1) = yR(ii) * nl(2*ii-1);
        at(2*ii,2*ii) = yR(ii) * nl(2*ii);
    end
    
    if isinf(dfy)
        lhood_hess = (H'/R)*H;
    else    
        lhood_hess = (dfy+do)*( H'*(R\H) - 2*H'*(yR*yR')*H/(dfy*tdist) - at )/(dfy*tdist);
    end
    
    Hess = prior_hess + lhood_hess;
    
    if ~isposdef(Hess)
        min_eig = min(eig(Hess));
        Hess = Hess - 2*min_eig*eye(ds);
        warning('Uh oh! The Hessian of the log of the optimal importance density is not positive definite at the maximum.');
    end
    
end

end

