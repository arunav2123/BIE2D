function [u ux uy info] = LapDLPeval_closeglobal(t, s, dens, side)
% LAPDLPEVAL_CLOSEGLOBAL - Laplace potential & deriv w/ global close-eval quad
%
% u = LapDLPeval_closeglobal(t,s,dens,side) returns potentials at targets t.x
%  due to double-layer potential with real-valued density dens sampled on the
%  nodes s.x of a smooth global quadrature rule on the curve s, either inside
%  outside the curve. The global scheme of [hel08] based on barycentric Cauchy
%  close-evaluation (see references in cauchycompeval.m) is used.
% 
% Our definition of the DLP on curve \Gamma is, associating R^2 with the complex
% plane, with x = (x_1,x_2) a point in the complex plane,
%
%    u(x) = Re (1/2\pi i) \int_\Gamma \tau(y) / (x-y) dy
%
% Inputs:
%  t = target struct containing
%      t.x = M-by-1 list of targets, as points in complex plane
%      (optionally also t.nx target normals as unit complex numbers)
%  s = curve struct containing N-by-1 vector s.x of source nodes (as complex
%     numbers), and other fields as generated by setupquad.
%     s.a one interior point far from bdry (mean(s.x) used if not provided)
%  dens = double-layer density values at nodes. Note, must be real-valued.
%     Further, if dens has multiple columns, the evaluation is done for each.
%  side = 'i','e' to indicate targets are interior or exterior to the curve.
%
% Outputs:
%  u = column vector of M potential values where M = numel(t.x), or if
%      dens has n columns, the n column vector outputs are stacked (M-by-n).
%  [u un] = LapDLPeval_closeglobal(t,s,dens,side) also returns target-normal
%           derivatives (M-by-n) using t.nx
%  [u ux uy] = LapDLPeval_closeglobal(t,s,dens,side) instead returns x- and y-
%           partials of u at the targets (ignores t.nx)
%  [u ux uy info] = LapDLPeval_closeglobal(t,s,dens,side) also gives diagnostic:
%           info.vb = vector of v boundary values (M-by-n)
%           info.imv = imag part of v at targets (M-by-n)
%
% Notes: * complex-valued dens may be used if you know what you're doing
%          (eg this is used by the Stokes close-evaluation).
%
% References:
%
%  [hel08] J. Helsing and R. Ojala, On the evaluation of layer potentials close
%          to their sources, J. Comput. Phys., 227 (2008), pp. 2899–292
%
%  [lsc2d] Spectrally-accurate quadratures for evaluation of layer potentials
%          close to the boundary for the 2D Stokes and Laplace equations,
%          A. H. Barnett, B. Wu, and S. Veerapaneni, SIAM J. Sci. Comput.,
%          37(4), B519-B542 (2015)   https://arxiv.org/abs/1410.2187
%
% See also: LAPDLPEVAL, SETUPQUAD, CAUCHYCOMPEVAL, LAPINTDIRBVP
%
% complexity O(N^2) for evaluation of v^+ or v^-, plus O(NM) for globally
% compensated quadrature to targets

% Barnett 2013; multiple-column generalization by Gary Marple, 2014.
% Repackaged Barnett 6/12/16

if nargin==0, test_LapDLPevalfar; return; end
n = size(dens,2);                   % # dens columns
N = numel(s.x);                     % # source nodes

% Helsing step 1: eval bdry limits at nodes of v = complex DLP(tau)...
vb = zeros(N,n);                    % alloc v^+ or v^- bdry data of holom func
densp = zeros(N,n);                 % alloc tau'
for k=1:n
    densp(:,k) = perispecdiff(dens(:,k));  % numerical deriv of each dens
end
for i=1:N, j = [1:i-1, i+1:N];      % skip pt i. Eqn (4.2) in [lsc2d]
  vb(i,:) = sum((dens(j,:)-ones(N-1,1)*dens(i,:))./((s.x(j)-s.x(i))*ones(1,n)).*(s.cw(j)*ones(1,n)),1) + densp(i,:)*s.w(i)/s.sp(i);   % vectorized over cols
end
vb = vb*(1/(-2i*pi));               % prefactor
if side=='i', vb = vb - dens; end   % JR's add for v^-, cancel for v^+ (Eqn 4.3)
info.vb = vb;                       % diagnostics

% Helsing step 2: compensated close-evaluation of u = Re(v) & its deriv...
if nargout>1                                % want derivatives
  [v vp] = cauchycompeval(t.x,s,vb,side);   % does Sec. 3 of [lsc2d]
  ux = real(vp)'; uy = -imag(vp)';          % leave as partials...
  if nargout==2, ux = ux.*real(t.nx) + uy.*imag(t.nx); end % or dot w/ targ nor
else
  v = cauchycompeval(t.x,s,vb,side);        % does Sec. 3 of [lsc2d]
end
u = real(v)'; info.imv = imag(v)';        % col vecs *** check for n>1 case

%%%%%%%%%%%%%%%%%%%
function test_LapDLPevalfar         % check far-field matches the native rule
s = wobblycurve(0.3,5,200); figure; showsegment(s);
tau = sin(3*s.t);                        % pick smooth density
nt = 100; t.nx = exp(2i*pi*rand(nt,1));  % target normals
for side = 'ie'
  if side=='e', t.x = 1.5+1i+rand(nt,1)+1i*rand(nt,1);         % distant targs
  else, t.x = 0.6*(rand(nt,1)+1i*rand(nt,1)-(0.5+0.5i)); end % targs far inside
  plot(t.x,'.');
  [u un] = LapDLPeval(t,s,tau);
  [uc unc] = LapDLPeval_closeglobal(t,s,tau,side);
  side, max(abs(u-uc)), max(abs(un-unc))
end

