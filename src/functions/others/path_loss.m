function loss = path_loss(d, f)
% Description: Gets the FSPL (Free Space Path Loss) according to the distance and frequency.
% Arguments:
%   d: Distance in meters.
%   f: Frequency in Hz.
% Returns:
%   loss: Path loss value.

    loss = 20*log10(d) + 20*log10(f) - 147.55;
end