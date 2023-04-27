function step3p2_export_incr_toBIDS(BIDS_path, deriv_name, only_with_Raw_present)
%step3p2_export_incr_toBIDS OCnvert the end result to BIDS derivative
%   The end reuslt is inehrently a noise rejection method and dipfit
%   analysis. So, the end result should be handiliy transferrable to the
%   BIDS derivative format.
%
%   INPUTS:
%       BIDS_path: the path to the raw BIDS path
%       deriv_name: name of the folder under derivatives to store the data
%       only_with_raw_present: Only stores the final datasetst that their
%       respective raw data is avaiable. true | false, default: true
%
% (c) Seyed Yahya Shirazi, 04/2023, UCSD, INC, SCCN
