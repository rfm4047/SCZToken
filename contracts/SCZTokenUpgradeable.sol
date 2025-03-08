// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SCZTokenUpgradeable is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    // La función initializer reemplaza al constructor
    function initialize() public initializer {
        __ERC20_init("SCZ Token", "SCZ");
        __Ownable_init(msg.sender);
        // Ejemplo: acuñar 1,000,000 tokens al deployer
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    // Función para acuñar tokens adicionales (soloOwner)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
