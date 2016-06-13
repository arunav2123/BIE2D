function [A,P,T] = StoDLPmat(t,s,mu)
% STODLPMAT   Matrices for Stokes double-layer velocity, pressure, and traction.
%
% [A,P,T] = StoDLPmat(t,s,mu) returns dense matrices taking double-layer
%  density values on the nodes of a source curve to velocity, pressure, and
%  traction on the nodes of a target curve. Native quadrature is used, apart
%  from when target=source when A is the self-interaction Nystrom matrix using
%  the smooth diagonal-limit formula for DLP.
%
% The normalization is as in Sec 2.3 of [HW], and [Mar15].
%
% References:
%  [HW]    "Boundary Integral Equations", G. C. Hsiao and W. L. Wendland
%          (Springer, 2008).
%
%  [Mar15] "A fast algorithm for simulating multiphase flows through periodic
%          geometries of arbitrary shape," G. Marple, A. H. Barnett,
%          A. Gillman, and S. Veerapaneni, in press, SIAM J. Sci. Comput.
% 	   https://arXiv.org/abs/1510.05616
%
% Inputs: (see setupquad for source & target struct definitions)
%  s = source segment struct with s.x nodes, s.w weights on [0,2pi),
%      s.sp speed function |Z'| at the nodes, and s.tang tangent angles.
%  t = target segment struct with t.x nodes, and t.nx normals if traction needed
%  mu = viscosity
%
% Outputs:
%  A = 2M-by-2N matrix taking density (force vector) to velocity on the
%      target curve. As always for Stokes, ordering is nodes fast,
%      components (1,2) slow, so that A has 4 large blocks A_11, A_12, etc.
%  P = M-by-2N matrix taking density to pressure (scalar) on target nodes.
%  T = 2M-by-2N matrix taking density to normal traction on target nodes.
%
% Notes: 1) no self-evaluation for P or T.
%
% To test use STOINTDIRBVP
%
% See also: SETUPQUAD

% Barnett 6/13/16

N = numel(s.x); M = numel(t.x);
r = repmat(t.x, [1 N]) - repmat(s.x.', [M 1]);    % C-# displacements mat
irr = 1./(conj(r).*r);    % 1/r^2, used in all cases below
d1 = real(r); d2 = imag(r);
rdotny = d1.*repmat(real(s.nx)', [M 1]) + d2.*repmat(imag(s.nx)', [M 1]);
rdotnir4 = rdotny.*(irr.*irr); if nargout==1, clear rdotny; end
A12 = (1/pi)*d1.*d2.*rdotnir4;  % off diag vel block
A = [(1/pi)*d1.^2.*rdotnir4,   A12;                     % Ladyzhenskaya
     A12,                      (1/pi)*d2.^2.*rdotnir4];
if sameseg(t,s)         % self-int DLP velocity diagonal correction
  c = -s.cur/2/pi;           % diagonal limit of Laplace DLP
  tx = 1i*s.nx; t1=real(tx); t2=imag(tx);     % tangent vectors on the curve
  A(sub2ind(size(A),1:N,1:N)) = c.*t1.^2;     % overwrite diags of 4 blocks
  A(sub2ind(size(A),1+N:2*N,1:N)) = c.*t1.*t2;
  A(sub2ind(size(A),1:N,1+N:2*N)) = c.*t1.*t2;
  A(sub2ind(size(A),1+N:2*N,1+N:2*N)) = c.*t2.^2;
end
A = A .* repmat([s.w(:)' s.w(:)'], [2*M 1]);            % quadr wei
if nargout>1           % pressure of DLP (no self-int)
  P = [(mu/pi)*(-repmat(real(s.nx)', [M 1]).*irr + 2*rdotnir4.*d1), ...
       (mu/pi)*(-repmat(imag(s.nx)', [M 1]).*irr + 2*rdotnir4.*d2)  ];
  P = P .* repmat([s.w(:)' s.w(:)'], [M 1]);           % quadr wei
end
if nargout>2           % traction, my derivation of formula (no self-int)
  nx1 = repmat(real(t.nx), [1 N]); nx2 = repmat(imag(t.nx), [1 N]);
  rdotnx = d1.*nx1 + d2.*nx2;
  ny1 = repmat(real(s.nx)', [M 1]); ny2 = repmat(imag(s.nx)', [M 1]);
  dx = rdotnx.*irr; dy = rdotny.*irr; dxdy = dx.*dy;
  R12 = d1.*d2.*irr; R = [d1.^2.*irr, R12; R12, d2.^2.*irr];
  nydotnx = nx1.*ny1 + nx2.*ny2;
  T = R.*kron(ones(2), nydotnx.*irr - 8*dxdy) + kron(eye(2), dxdy);
  T = T + [nx1.*ny1.*irr, nx1.*ny2.*irr; nx2.*ny1.*irr, nx2.*ny2.*irr] + ...
      kron(ones(2),dx.*irr) .* [ny1.*d1, ny1.*d2; ny2.*d1, ny2.*d2] + ...
      kron(ones(2),dy.*irr) .* [d1.*nx1, d1.*nx2; d2.*nx1, d2.*nx2];
  T = (mu/pi) * T;                                        % prefac
  T = T .* repmat([s.w(:)' s.w(:)'], [2*M 1]);            % quadr wei
end
