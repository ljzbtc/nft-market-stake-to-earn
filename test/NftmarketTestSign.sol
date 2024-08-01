// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NftMarket.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract NftMarketTest is Test {
    NftMarket public market;
    MockNFT public nft;
    MockERC20 public erc20;

    address public seller = address(1);
    address public buyer = address(2);
    address public nftOwner = address(3);

    uint256 private sellerPrivateKey;
    uint256 private buyerPrivateKey;

    function setUp() public {
        nft = new MockNFT();
        erc20 = new MockERC20();
        market = new NftMarket(address(erc20), nftOwner);

        sellerPrivateKey = 0xA11CE;
        buyerPrivateKey = 0xB0B;

        seller = vm.addr(sellerPrivateKey);
        buyer = vm.addr(buyerPrivateKey);

        nft.mint(seller, 1);
        vm.prank(seller);
        nft.approve(address(market), 1);

        erc20.transfer(buyer, 100 * 10**18);
    }

    function testBuyWithSignaturesERC20() public {
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(seller);
        market.listItem(address(nft), 1, price, address(erc20));

        NftMarket.LimitOrder memory order = NftMarket.LimitOrder({
            seller: seller,
            nft: address(nft),
            tokenId: 1,
            payToken: address(erc20),
            price: price,
            deadline: deadline
        });

        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 limitOrderTypeHash = keccak256("LimitOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(
            limitOrderTypeHash,
            order.seller,
            order.nft,
            order.tokenId,
            order.payToken,
            order.price,
            order.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        vm.startPrank(buyer);
        erc20.approve(address(market), price);
        market.buy_with_signatures(order, v, r, s);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), buyer);
        //market will charge 0.5% fee


        assertEq(erc20.balanceOf(address(market)), price * 5 / 1000);

        //seller will get 99.5% of the price
        assertEq(erc20.balanceOf(seller), price * 995 / 1000);
        
    }

    function testBuyWithSignaturesEth() public {
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(seller);
        market.listItem(address(nft), 1, price, address(0));

        NftMarket.LimitOrder memory order = NftMarket.LimitOrder({
            seller: seller,
            nft: address(nft),
            tokenId: 1,
            payToken: address(0),
            price: price,
            deadline: deadline
        });

        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 limitOrderTypeHash = keccak256("LimitOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(
            limitOrderTypeHash,
            order.seller,
            order.nft,
            order.tokenId,
            order.payToken,
            order.price,
            order.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        vm.prank(buyer);
        vm.deal(buyer, price);
        market.buy_with_signatures{value: price}(order, v, r, s);

        // the market will charge 0.5% fee
        assertEq(address(market).balance, price * 5 / 1000);

        assertEq(nft.ownerOf(1), buyer);

        //seller will get 99.5% of the price

        assertEq(address(seller).balance, price * 995 / 1000);
    }

    function testFailBuyWithExpiredSignature() public {
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp - 1 hours; // Expired deadline

        vm.prank(seller);
        market.listItem(address(nft), 1, price, address(erc20));

        NftMarket.LimitOrder memory order = NftMarket.LimitOrder({
            seller: seller,
            nft: address(nft),
            tokenId: 1,
            payToken: address(erc20),
            price: price,
            deadline: deadline
        });

        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 limitOrderTypeHash = keccak256("LimitOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(
            limitOrderTypeHash,
            order.seller,
            order.nft,
            order.tokenId,
            order.payToken,
            order.price,
            order.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        vm.startPrank(buyer);
        erc20.approve(address(market), price);
        market.buy_with_signatures(order, v, r, s); // This should fail due to expired deadline
        vm.stopPrank();
    }

    function testFailBuyWithInvalidSignature() public {
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(seller);
        market.listItem(address(nft), 1, price, address(erc20));

        NftMarket.LimitOrder memory order = NftMarket.LimitOrder({
            seller: seller,
            nft: address(nft),
            tokenId: 1,
            payToken: address(erc20),
            price: price,
            deadline: deadline
        });

        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 limitOrderTypeHash = keccak256("LimitOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(
            limitOrderTypeHash,
            order.seller,
            order.nft,
            order.tokenId,
            order.payToken,
            order.price,
            order.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest); // Signing with buyer's key instead of seller's

        vm.startPrank(buyer);
        erc20.approve(address(market), price);
        market.buy_with_signatures(order, v, r, s); // This should fail due to invalid signature
        vm.stopPrank();
    }
}