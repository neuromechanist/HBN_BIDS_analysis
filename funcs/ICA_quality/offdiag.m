function [od] = offdiag(vec, r, n)
% OFFDIAG Computes the off-diagonal cost for a given row/column placement.
%   od = offdiag(vec, r, n) computes the off-diagonal cost for placing a
%   particular row/column in a specific position in a matrix. The input
%   arguments are:
%       - vec: Row or column vector representing the values of the row/column.
%       - r: Position index for the row/column placement.
%       - n: Size of the matrix.
% (c) Seyed Yahya Shirazi, 04/2023 UCSD, INC, SCCN

    J = 1:n;
    diffVector = abs(J - r).^0.9 / r^0;
    diffVector(r) = 0;
    od = sum(vec .* diffVector);
end
