function plan = bessel_build_z_plan(params)
%BESSEL_BUILD_Z_PLAN Bounded, deterministic observation-plane scheduling.
% params must have resolved optical positions (the engine 'plan' action does
% this). Refinement adds observation planes; it does not change propagation.
s = params.simulation;
s = localDefault(s, 'zSamplingMode', 'uniform');
s = localDefault(s, 'zRefinementRegionsMm', zeros(0,3));
s = localDefault(s, 'zExtraPlanesMm', zeros(1,0));
s = localDefault(s, 'maxZPlanes', 20000);
s = localDefault(s, 'useBPM', true);
s = localDefault(s, 'propagationMethod', 'adaptiveCollins');
if ~(ischar(s.zSamplingMode) || (isstring(s.zSamplingMode) && isscalar(s.zSamplingMode))) || ...
        ~any(strcmp(s.zSamplingMode, {'uniform','local'}))
    error('Bessel:ZPlan:InvalidMode', 'zSamplingMode must be uniform or local.');
end
mode = char(s.zSamplingMode);
localScalar(s.zRangeMm, 0, false, 'zRangeMm');
localScalar(s.dzMm, 0, true, 'dzMm');
localScalar(s.maxZPlanes, 0, true, 'maxZPlanes');
if s.maxZPlanes ~= fix(s.maxZPlanes)
    error('Bessel:ZPlan:InvalidRegion', 'maxZPlanes must be a positive integer.');
end
regions = s.zRefinementRegionsMm;
if ~isnumeric(regions) || ~isreal(regions) || ~ismatrix(regions) || ...
        size(regions,2) ~= 3 || any(~isfinite(regions(:)))
    error('Bessel:ZPlan:InvalidRegion', 'zRefinementRegionsMm must be a finite real K-by-3 matrix.');
end
extra = s.zExtraPlanesMm;
if ~isnumeric(extra) || ~isreal(extra) || (~isempty(extra) && ~isvector(extra)) || ...
        any(~isfinite(extra(:)))
    error('Bessel:ZPlan:InvalidExtraPlane', 'zExtraPlanesMm must be a finite real vector.');
end
regions = double(regions);
extra = double(extra(:).');
tol = 32*eps(max(1,double(s.zRangeMm)));
events = zeros(1,0);
names = {'lens1','lens2','sample'};
for k = 1:numel(names)
    name = names{k};
    if params.optics.([name 'Enabled'])
        position = params.optics.([name 'PositionMm']);
        if ~isnumeric(position) || ~isreal(position) || ~isscalar(position) || ...
                ~isfinite(position) || position < 0
            error('Bessel:ZPlan:InvalidRegion', 'Enabled optical positions must be finite and nonnegative.');
        end
        if position <= s.zRangeMm
            events(end+1) = double(position); %#ok<AGROW>
        end
    end
end
events = unique(events);
segments = zeros(0,3);
if ~s.useBPM
    % Preserve syntactically valid settings for a future propagation run.
    z = 0;
    baseCount = 1;
elseif strcmp(mode,'local')
    if ~strcmp(s.propagationMethod,'adaptiveCollins')
        error('Bessel:ZPlan:UnsupportedBackend', 'Local z sampling requires adaptiveCollins; legacyASM uses fixed steps.');
    end
    if isempty(regions) && isempty(extra)
        error('Bessel:ZPlan:InvalidRegion', 'Local sampling needs at least one region or extra plane.');
    end
    if any(regions(:,1) < 0 | regions(:,2) > s.zRangeMm | ...
            regions(:,1) >= regions(:,2) | regions(:,3) <= 0 | regions(:,3) > s.dzMm)
        error('Bessel:ZPlan:InvalidRegion', 'Each region needs 0 <= start < end <= zRangeMm and 0 < local dz <= base dz.');
    end
    if any(extra < 0 | extra > s.zRangeMm)
        error('Bessel:ZPlan:InvalidExtraPlane', 'Extra planes must lie in [0,zRangeMm].');
    end
    if any(regions(:,3) <= 8*tol)
        error('Bessel:ZPlan:SpacingTooSmall', 'Local dz is too small relative to floating-point precision.');
    end
    [base,basePriority] = localBase(s,events,tol);
    baseCount = numel(base);
    boundaries = unique(reshape(regions(:,1:2),1,[]));
    for k = 1:numel(boundaries)-1
        a = boundaries(k); b = boundaries(k+1);
        active = regions(:,1) <= a & regions(:,2) >= b;
        if ~any(active), continue; end
        h = min(regions(active,3));
        if ~isempty(segments) && segments(end,2) == a && segments(end,3) == h
            segments(end,2) = b;
        else
            segments(end+1,:) = [a,b,h]; %#ok<AGROW>
        end
    end
    protected = unique([0,double(s.zRangeMm),events,boundaries,extra]);
    localCap(numel(protected),s.maxZPlanes);
    [z,priority] = localMerge(protected,2*ones(size(protected)),base,basePriority,protected,tol,s.maxZPlanes);
    for k = 1:size(segments,1)
        fine = localSequence(segments(k,1),segments(k,2),segments(k,3),tol,s.maxZPlanes);
        [z,priority] = localMerge(z,priority,fine,zeros(size(fine)),protected,tol,s.maxZPlanes);
    end
else
    [z,~] = localBase(s,events,tol);
    baseCount = numel(z);
end
spacing = diff(z);
if isempty(spacing)
    minSpacing = []; maxSpacing = []; uniform = true;
else
    minSpacing = min(spacing); maxSpacing = max(spacing);
    uniform = all(abs(spacing-spacing(1)) <= tol);
end
plan = struct('schemaVersion',1, 'mode',mode, 'zValuesMm',z, ...
    'planeCount',numel(z), 'baseDzMm',double(s.dzMm), ...
    'basePlaneCount',baseCount, 'addedPlaneCount',numel(z)-baseCount, ...
    'requestedRegionsMm',regions, 'effectiveSegmentsMm',segments, ...
    'extraPlanesMm',extra, 'opticalEventZMm',events, ...
    'isUniformZ',uniform, 'zSpacingMm',spacing, ...
    'minSpacingMm',minSpacing, 'maxSpacingMm',maxSpacing, 'mergeToleranceMm',tol);
end

function [z,p] = localBase(s,events,tol)
localSequenceCount(0,double(s.zRangeMm),double(s.dzMm),tol,s.maxZPlanes);
% Use MATLAB's original colon rule (including its floating-point placement).
base = 0:double(s.dzMm):double(s.zRangeMm);
localCap(numel(base),s.maxZPlanes);
if strcmp(s.propagationMethod,'adaptiveCollins')
    protected = unique([0,double(s.zRangeMm),events]);
else
    % Legacy observes only its original colon grid, including its old end rule.
    protected = 0;
end
[z,p] = localMerge(protected,2*ones(size(protected)),base,ones(size(base)), ...
    protected,tol,s.maxZPlanes);
end

function z = localSequence(a,b,h,tol,cap)
count = localSequenceCount(a,b,h,tol,cap);
z = a+(0:count-1)*h;
z = z(z <= b);
end

function count = localSequenceCount(a,b,h,tol,cap)
if b > a && h <= 8*tol
    error('Bessel:ZPlan:SpacingTooSmall', 'dz is too small relative to floating-point precision.');
end
count = floor((b-a)/h)+1;
localCap(count,cap); % Before allocating any coordinate sequence.
end

function [z,p] = localMerge(z,p,incoming,ip,protected,tol,cap)
% Snap generated points to exact user/event coordinates first. Protected
% coordinates are never rounded or merged with distinct protected points.
if numel(protected) > 1
    nearest = interp1(protected,protected,incoming,'nearest','extrap');
elseif isempty(protected)
    nearest = inf(size(incoming));
else
    nearest = repmat(protected,size(incoming));
end
snap = ip < 2 & abs(incoming-nearest) <= tol;
incoming(snap) = nearest(snap); ip(snap) = 2;
[values,order] = sort([z,incoming]);
priorities = [p,ip]; priorities = priorities(order);
out = zeros(1,numel(values)); op = out; n = 0; k = 1;
while k <= numel(values)
    last = k;
    % Anchor each tolerance group to its first value, avoiding chain merging.
    while last < numel(values) && values(last+1)-values(k) <= tol
        last = last+1;
    end
    protectedIndex = find(priorities(k:last) == 2)+k-1;
    if ~isempty(protectedIndex)
        selected = protectedIndex([true,diff(values(protectedIndex)) ~= 0]);
    else
        [~,best] = max(priorities(k:last)); selected = k+best-1;
    end
    for j = selected
        n = n+1; localCap(n,cap);
        out(n) = values(j); op(n) = priorities(j);
    end
    k = last+1;
end
z = out(1:n); p = op(1:n);
end

function localCap(count,cap)
if ~isfinite(count) || count > cap
    error('Bessel:ZPlan:TooManyPlanes', 'Requested z sampling exceeds maxZPlanes=%d. Reduce the range or increase dz.',cap);
end
end

function localScalar(value,minimum,strict,name)
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < minimum || (strict && value == minimum)
    error('Bessel:ZPlan:InvalidRegion', '%s has an invalid value.',name);
end
end

function s = localDefault(s,name,value)
if ~isfield(s,name), s.(name) = value; end
end
