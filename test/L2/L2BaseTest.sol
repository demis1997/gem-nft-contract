// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { GemFactory } from "../../src/L2/GemFactory.sol";
import { GemFactoryProxy } from "../../src/L2/GemFactoryProxy.sol";
import { Treasury } from "../../src/L2/Treasury.sol";
import { TreasuryProxy } from "../../src/L2/TreasuryProxy.sol";
import { MarketPlace } from "../../src/L2/MarketPlace.sol";
import { MarketPlaceProxy } from "../../src/L2/MarketPlaceProxy.sol";
import { RandomPack } from "../../src/L2/RandomPack.sol";
import { RandomPackProxy } from "../../src/L2/RandomPackProxy.sol";
import { L2StandardERC20 } from "../../src/L2/L2StandardERC20.sol";
import { MockTON } from "../../src/L2/Mock/MockTON.sol";
import { GemFactoryStorage } from "../../src/L2/GemFactoryStorage.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { DRBCoordinatorMock } from "../../src/L2/Mock/DRBCoordinatorMock.sol";
import { DRBConsumerBase } from "../../src/L2/Randomness/DRBConsumerBase.sol";

import { Airdrop } from "../../src/L2/Airdrop.sol";
import { AirdropProxy } from "../../src/L2/AirdropProxy.sol";
import {IDRBCoordinator} from "../../src/interfaces/IDRBCoordinator.sol";


contract L2BaseTest is Test {

    using SafeERC20 for IERC20;

    uint256 public commonminingTry = 1;
    uint256 public rareminingTry = 2;
    uint256 public uniqueminingTry = 1; // for testing purpose
    uint256 public epicminingTry = 10;
    uint256 public LegendaryminingTry = 15;
    uint256 public MythicminingTry = 20;
    uint256 public tonFeesRate = 10; // 10%
    uint256 public miningFees = 0.01 ether;

    uint256 public CommonGemsValue = 10 * 10 ** 27;
    uint256 public RareGemsValue = 19 * 10 ** 27;
    uint256 public UniqueGemsValue = 53 * 10 ** 27;
    uint256 public EpicGemsValue = 204 * 10 ** 27;
    uint256 public LegendaryGemsValue = 605 * 10 ** 27;
    uint256 public MythicGemsValue = 4000 * 10 ** 27;

    uint256 public CommonGemsMiningPeriod = 1 weeks;
    uint256 public RareGemsMiningPeriod = 2 weeks;
    uint256 public UniqueGemsMiningPeriod = 3 weeks;
    uint256 public EpicGemsMiningPeriod = 4 weeks;
    uint256 public LegendaryGemsMiningPeriod = 5 weeks;
    uint256 public MythicGemsMiningPeriod = 6 weeks;

    uint256 public CommonGemsCooldownPeriod = 1 weeks;
    uint256 public RareGemsCooldownPeriod = 2 weeks;
    uint256 public UniqueGemsCooldownPeriod = 3 weeks;
    uint256 public EpicGemsCooldownPeriod = 4 weeks;
    uint256 public LegendaryGemsCooldownPeriod = 5 weeks;
    uint256 public MythicGemsCooldownPeriod = 6 weeks;

    address payable owner;
    address payable user1;
    address payable user2;
    address payable user3;

    GemFactory gemfactory;
    GemFactoryProxy gemfactoryProxy;
    address gemfactoryProxyAddress;
    Treasury treasury;
    TreasuryProxy treasuryProxy;
    address treasuryProxyAddress;
    MarketPlace marketplace;
    MarketPlaceProxy marketplaceProxy;
    address marketplaceProxyAddress;
    DRBCoordinatorMock drbCoordinatorMock;
    Airdrop airdrop;
    AirdropProxy airdropProxy;
    address airdropProxyAddress;
    RandomPack randomPack;
    RandomPackProxy randomPackProxy;
    address randomPackProxyAddress;
    
    address wston;
    address ton;
    address l1wston;
    address l1ton;
    address l2bridge;
    

    //DRB storage
    uint256 public avgL2GasUsed = 2100000;
    uint256 public premiumPercentage = 0;
    uint256 public flatFee = 0.001 ether;
    uint256 public calldataSizeBytes = 2071;

    //random pack storage
    uint256 randomPackFees = 40*10**18;
    uint256 randomBeaconFees = 0.005 ether;

    event CommonGemMinted();
    function setUp() public virtual {
        owner = payable(makeAddr("Owner"));
        user1 = payable(makeAddr("User1"));
        user2 = payable(makeAddr("User2"));
        user3 = payable(makeAddr("User3"));

        vm.startPrank(owner);
        vm.warp(1632934800);

        wston = address(new L2StandardERC20(l2bridge, l1wston, "Wrapped Ston", "WSTON")); // 27 decimals
        ton = address(new MockTON(l2bridge, l1ton, "Ton", "TON")); // 18 decimals

        vm.stopPrank();

        // mint some tokens to User1, user2 and user3
        vm.startPrank(l2bridge);
        L2StandardERC20(wston).mint(owner, 1000000 * 10 ** 27);
        L2StandardERC20(wston).mint(user1, 100000 * 10 ** 27);
        L2StandardERC20(wston).mint(user2, 100000 * 10 ** 27);
        L2StandardERC20(wston).mint(user3, 100000 * 10 ** 27);
        MockTON(ton).mint(user1, 1000000 * 10 ** 18);
        MockTON(ton).mint(user1, 100000 * 10 ** 18);
        MockTON(ton).mint(user2, 100000 * 10 ** 18);
        MockTON(ton).mint(user3, 100000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(owner);
        // give ETH to User1 to cover gasFees associated with using VRF functions
        vm.deal(user1, 100 ether);

        // deploy DRBCoordinatorMock
        drbCoordinatorMock = new DRBCoordinatorMock(
            avgL2GasUsed,
            premiumPercentage,
            flatFee,
            calldataSizeBytes
        );

        // deploy GemFactory
        gemfactory = new GemFactory();
        gemfactoryProxy = new GemFactoryProxy();
        gemfactoryProxy.upgradeTo(address(gemfactory));
        gemfactoryProxyAddress = address(gemfactoryProxy);

        // deploy and initialize treasury
        treasury = new Treasury();
        treasuryProxy = new TreasuryProxy();
        treasuryProxy.upgradeTo(address(treasury));
        treasuryProxyAddress = address(treasuryProxy);
        Treasury(treasuryProxyAddress).initialize(
            wston,
            ton,
            gemfactoryProxyAddress
        );

        // deploy and initialize marketplace
        marketplace = new MarketPlace();
        marketplaceProxy = new MarketPlaceProxy();
        marketplaceProxy.upgradeTo(address(marketplace));
        marketplaceProxyAddress = address(marketplaceProxy);
        MarketPlace(marketplaceProxyAddress).initialize(
            treasuryProxyAddress,
            gemfactoryProxyAddress,
            tonFeesRate,
            wston,
            ton
        );

        vm.stopPrank();

        // mint some TON & WSTON to treasury
        vm.startPrank(l2bridge);
        L2StandardERC20(wston).mint(treasuryProxyAddress, 100000 * 10 ** 27);
        MockTON(ton).mint(treasuryProxyAddress, 100000 * 10 ** 18);

        vm.stopPrank();


        vm.startPrank(owner);
        // initialize gemfactory with newly created contract addreses
        GemFactory(gemfactoryProxyAddress).initialize(
            address(drbCoordinatorMock),
            owner,
            wston,
            ton,
            treasuryProxyAddress,
            CommonGemsValue,
            RareGemsValue,
            UniqueGemsValue,
            EpicGemsValue,
            LegendaryGemsValue,
            MythicGemsValue
        );

        GemFactory(gemfactoryProxyAddress).setGemsMiningPeriods(
            CommonGemsMiningPeriod,
            RareGemsMiningPeriod,
            UniqueGemsMiningPeriod,
            EpicGemsMiningPeriod,
            LegendaryGemsMiningPeriod,
            MythicGemsMiningPeriod
        );

        GemFactory(gemfactoryProxyAddress).setGemsCooldownPeriods(
            CommonGemsCooldownPeriod,
            RareGemsCooldownPeriod,
            UniqueGemsCooldownPeriod,
            EpicGemsCooldownPeriod,
            LegendaryGemsCooldownPeriod,
            MythicGemsCooldownPeriod
        );

        GemFactory(gemfactoryProxyAddress).setMiningTrys(
            commonminingTry,
            rareminingTry,
            uniqueminingTry,
            epicminingTry,
            LegendaryminingTry,
            MythicminingTry
        );

        GemFactory(gemfactoryProxyAddress).setMarketPlaceAddress(marketplaceProxyAddress);
        Treasury(treasuryProxyAddress).setMarketPlace(marketplaceProxyAddress);
        Treasury(treasuryProxyAddress).approveGemFactory();
        Treasury(treasuryProxyAddress).wstonApproveMarketPlace();
        Treasury(treasuryProxyAddress).tonApproveMarketPlace();
    

        // We deploy the RandomPack contract
        randomPack = new RandomPack();
        randomPackProxy = new RandomPackProxy();
        randomPackProxy.upgradeTo(address(randomPack));
        randomPackProxyAddress = address(randomPackProxy);
        RandomPack(randomPackProxyAddress).initialize(
            address(drbCoordinatorMock),
            ton,
            gemfactoryProxyAddress,
            treasuryProxyAddress,
            randomPackFees
        );

        Treasury(treasuryProxyAddress).setRandomPack(randomPackProxyAddress);

        // we set up the list of colors available for the GEM
        GemFactory(gemfactoryProxyAddress).addColor("Ruby",0,0);
        GemFactory(gemfactoryProxyAddress).addColor("Ruby/Amber",0,1);
        GemFactory(gemfactoryProxyAddress).addColor("Amber",1,1);
        GemFactory(gemfactoryProxyAddress).addColor("Topaz",2,2);
        GemFactory(gemfactoryProxyAddress).addColor("Topaz/Emerald",2,3);
        GemFactory(gemfactoryProxyAddress).addColor("Emerald/Topaz",3,2);
        GemFactory(gemfactoryProxyAddress).addColor("Emerald",3,3);
        GemFactory(gemfactoryProxyAddress).addColor("Emerald/Amber",3,1);
        GemFactory(gemfactoryProxyAddress).addColor("Turquoise",4,4);
        GemFactory(gemfactoryProxyAddress).addColor("Sapphire",5,5);
        GemFactory(gemfactoryProxyAddress).addColor("Amethyst",6,6);
        GemFactory(gemfactoryProxyAddress).addColor("Amethyst/Amber",6,1);
        GemFactory(gemfactoryProxyAddress).addColor("Garnet",7,7);

        //deploying and initializing the airdrop contract
        airdrop = new Airdrop();
        airdropProxy = new AirdropProxy();
        airdropProxy.upgradeTo(address(airdrop));
        airdropProxyAddress = address(airdropProxy);
        Airdrop(airdropProxyAddress).initialize(treasuryProxyAddress, gemfactoryProxyAddress);

        // set the airdrop address in treasury and gemfactory
        Treasury(treasuryProxyAddress).setAirdrop(airdropProxyAddress);
        GemFactory(gemfactoryProxyAddress).setAirdrop(airdropProxyAddress);

        vm.stopPrank();
    }


    function testSetup() public view {
        address wstonAddress = GemFactory(gemfactoryProxyAddress).getWstonAddress();
        assert(wstonAddress == address(wston));

        address tonAddress = GemFactory(gemfactoryProxyAddress).getTonAddress();
        assert(tonAddress == address(ton));

        address treasuryAddress = GemFactory(gemfactoryProxyAddress).getTreasuryAddress();
        assert(treasuryAddress == treasuryProxyAddress);

        // Check that the Treasury has approved the GemFactory to spend WSTON
        uint256 allowance = IERC20(wston).allowance(treasuryProxyAddress, address(gemfactoryProxyAddress));
        assert(allowance == type(uint256).max);
    }
}
