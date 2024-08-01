// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NftMarket {
    error NftMarketplace_NotApprovedForMarketplace();
    error NftMarketplace_NotListed(
        address nftAddress,
        uint256 tokenId,
        address payToken
    );
    error NftMarketplace_NotEnoughFunds();
    error NftMarketplace_InvalidPayment();

    event NftMarketplace_Listed(
        address indexed token_address,
        uint256 indexed tokenId,
        uint256 sale_price,
        address payToken
    );
    event NftMarketplace_Bought(
        address indexed token_address,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price,
        address payToken
    );

    address public immutable IEC20_TOKEN_ADDRESS;
    address public immutable NFT_OWNER;
    uint256 public immutable MARKET_FEE = 5; // 0.5%
    uint256 public immutable MIN_PRICE = 1000;

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }
    struct NftWhiteList {
        address wallet;
    }

    struct LimitOrder {
        address seller;
        address nft;
        uint256 tokenId;
        address payToken;
        uint256 price;
        uint256 deadline;
    }


    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 constant NFT_WHITHE_TYPEHASH =
        keccak256("Nft_witheList(address wallet)");

    bytes32 private constant LIMIT_ORDER_TYPE_HASH =
        keccak256(
            "LimitOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)"
        );

    // 为了支持多种代币支付
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public nftList;

    constructor(address _IEC20_TOKEN, address _NFT_OWNER) {
        IEC20_TOKEN_ADDRESS = _IEC20_TOKEN;
        NFT_OWNER = _NFT_OWNER;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256("NftMarket"),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function listItem(
        address token_address,
        uint256 tokenId,
        uint256 sale_price,
        address payToken
    ) public {
        IERC721 nft = IERC721(token_address);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nft.getApproved(tokenId) == address(this),
            "Not approved for marketplace"
        );
        require(sale_price >= MIN_PRICE, "Price too low");
        nftList[token_address][tokenId][payToken] = sale_price;
        emit NftMarketplace_Listed(
            token_address,
            tokenId,
            sale_price,
            payToken
        );
    }

    function buy_with_signatures(
        LimitOrder memory limitOrder,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        LIMIT_ORDER_TYPE_HASH,
                        limitOrder.seller,
                        limitOrder.nft,
                        limitOrder.tokenId,
                        limitOrder.payToken,
                        limitOrder.price,
                        limitOrder.deadline
                    )
                )
            )
        );
        require(
            ecrecover(digest, v, r, s) == limitOrder.seller,
            "invalid signature"
        );
        require(block.timestamp <= limitOrder.deadline, "Order expired");
        _buynft(
            limitOrder.nft,
            limitOrder.tokenId,
            limitOrder.price,
            limitOrder.payToken
        );
    }
    function ethStake(uint256 amount) public payable {
        require(msg.value == amount, "Invalid amount");
    }

    function _buynft(
        address token_address,
        uint256 tokenId,
        uint256 buy_token_amount,
        address payToken
    ) public payable {
        uint256 price = nftList[token_address][tokenId][payToken];
        if (price <= 0) {
            revert NftMarketplace_NotListed(token_address, tokenId, payToken);
        }

        uint256 fee = (price * MARKET_FEE) / 1000;
        uint256 sellerAmount = price - fee;

        if (buy_token_amount < price) {
            revert NftMarketplace_NotEnoughFunds();
        }

        IERC721 nft = IERC721(token_address);
        address seller = nft.ownerOf(tokenId);

        if (payToken == address(0)) {
            // ETH payment
            if (msg.value < price) {
                revert NftMarketplace_NotEnoughFunds();
            }

            payable(seller).transfer(sellerAmount);

            if (msg.value > price) {
                payable(msg.sender).transfer(msg.value - price);
            }
        } else {
            // ERC20 payment
            if (msg.value > 0) {
                revert NftMarketplace_InvalidPayment();
            }
            IERC20(payToken).transferFrom(msg.sender, seller, sellerAmount);
            IERC20(payToken).transferFrom(msg.sender, address(this), fee);
        }

        nft.safeTransferFrom(seller, msg.sender, tokenId);
        delete nftList[token_address][tokenId][payToken];

        emit NftMarketplace_Bought(
            token_address,
            tokenId,
            msg.sender,
            price,
            payToken
        );
    }

    function hashStruct(
        EIP712Domain memory eip712Domain
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    function verifyBuy(
        address wallet,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address token_address,
        uint256 tokenId,
        uint256 buy_token_amount,
        address payToken
    ) public payable {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(NFT_WHITHE_TYPEHASH, wallet))
            )
        );
        require(ecrecover(digest, v, r, s) == NFT_OWNER, "not whitelisted");

        _buynft(token_address, tokenId, buy_token_amount, payToken);
    }





}
