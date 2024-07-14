//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/pension.sol";
import "../contracts/storageLib.sol";
import "./DeployHelpers.s.sol";
import {MintableSuperToken} from "../test/MintableSuperToken.sol";

interface IMint {
    function initialize(address factory, string memory _name, string memory _symbol) external;
    function mint(address to, uint256 amount ) external;
}

contract DeployScript is ScaffoldETHDeploy {
  error InvalidPrivateKey(string);

  function run() external {
    uint256 deployerPrivateKey = setupLocalhostEnv();
    if (deployerPrivateKey == 0) {
      revert InvalidPrivateKey(
        "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
      );
    }
    vm.startBroadcast(deployerPrivateKey);



    //create token
    // address STFactory = 0x254C2e152E8602839D288A7bccdf3d0974597193; //eth sepolia
    address STFactory = 0x87560833d59Be057aFc63cFFa3fc531589Ba428F;
    //BASE 0xe20B9a38E0c96F61d1bA6b42a61512D56Fea1Eb3;

    ISuperToken time = ISuperToken(address(new MintableSuperToken()));
    IMint mintTime = IMint(address(time));
    
    console.log("deployed time: ", address(time));
    mintTime.initialize(STFactory, "time", "time");
    console.log("initialize time");

    ISuperToken cash = ISuperToken(address(new MintableSuperToken()));
    IMint mintCash = IMint(address(cash));
    
    console.log("deployed cash: ", address(cash));
    mintCash.initialize(STFactory, "cash", "cash");
    console.log("initialize cash");

    Pensions pensionContract = new Pensions(cash, time);
    address pensionContractAddress = address(pensionContract);
    
    mintTime.mint(pensionContractAddress, 1e22 ether);
    mintCash.mint(0xAA7dBAdAA2F1ADed7e9299947B3a94ea35eaB069, 1e22 ether);
    console.log("deployed pensionContract: ", address(pensionContract));

    vm.stopBroadcast();

    /**
     * This function generates the file containing the contracts Abi definitions.
     * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
     * This function should be called last.
     */
    exportDeployments();
  }

  function test() public { }
}
