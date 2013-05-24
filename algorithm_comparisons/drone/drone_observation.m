function [ obs, prob ] = drone_observation( model, state, obs )
%drone_observation Sample and/or evaluate observation density for the
%drone model.

% prob is a log-probability.

% Calculate observation mean
mn = drone_h(model, state);

% Sample observation if not provided
if (nargin<3)||isempty(obs)
    obs = mvnrnd(mn', model.R)';
end

% Calculate probability if required
if nargout>1
    
    % Resolve bearing ambiguity
    dy = obs - mn;
    if dy(1) > pi
        dy(1) = dy(1) - 2*pi;
    elseif dy(1) < -pi
        dy(1) = dy(1) + 2*pi;
    end
    
    prob = loggausspdf(dy, zeros(size(dy)), model.R);
else
    prob = [];
end

end

