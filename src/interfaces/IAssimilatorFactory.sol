// SPDX-License-Identifier: MIT

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.13;

import "../assimilators/AssimilatorV2.sol";

interface IAssimilatorFactory {
    function getAssimilator(address _token) external view returns (AssimilatorV2);

    function newAssimilator(
        address _oracle,
        address _token,
        uint256 _tokenDecimals
    ) external returns (AssimilatorV2);
}
