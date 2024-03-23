//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Hasher} from "./MiMCSponge.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";

contract Tornado is ReentrancyGuard {
    Hasher public hasher;

    // Merkle Tree: Can process 2^10 = 1024 leaf node for deposits
    uint8 public treeLevel = 10;
    uint256 public constant DENOMINATION = 1 ether;

    /* When a new deposit commitment is added to the Merkle tree, 
    it is placed at the location indicated by nextLeafIdex, 
    which is then incremented so that the next deposit commitment knows where it should be placed. */
    uint256 public nextLeafIdex = 0;

    // Storing the history of Merkle tree roots
    mapping(uint256 => bool) public roots;
    mapping(uint8 => uint256) public lastLevelHash;
    // Prevent double spending
    mapping(uint256 => bool) public nullifierHashs;
    mapping(uint256 => bool) public commitments;

    uint256[10] levelDefaults = [
        96203452318750999908428454193706286135948977640678371184232379276209525313523,
        55226891951956626373028658136598318915776321229684355582304234122097402342914,
        69818458493260830479308406784255555185891711442998254833072862471426915740367,
        7608667270840240591203663759571510380746798085563624084125285753680016829903,
        83587105579313004870967347925149792441851739297074708888784987781767442769810,
        109449340956139041756136222243572310530284321988098252296150001343832530687643,
        75736964883600798570394158677026783977927324377516022334167573168931188227661,
        97380648565217273888003964070807252469197301499964964936690636197819993676395,
        30616477050580205228098902597845003160548554913840496584284164111158122087135,
        33661038088629468924807864038050025350214116823107928530980956189973152781286
    ];

    event Deposit(
        uint256 indexed root,
        uint256[10] hashPairings,
        uint8[10] pairDirection
    );

    constructor(address _hasher) {
        hasher = Hasher(_hasher);
        // verifier = Verifier(_verifier);
    }

    function deposit(uint256 _commitment) external payable nonReentrant {
        require(msg.value == DENOMINATION, "incorrect amount");
        require(!commitments[_commitment], "duplicate commitment hash");
        require(nextLeafIdex < 2 ** treeLevel, "tree full");

        uint256 newRoot; // Merkle tree root
        uint256[10] memory hashPairings;
        uint8[10] memory hashDirections;

        uint256 currentIdx = nextLeafIdex;
        uint256 currentHash = _commitment;

        uint256 left;
        uint256 right;
        uint256[2] memory ins;

        for (uint8 i = 0; i < treeLevel; i++) {
            lastLevelHash[treeLevel] = currentHash;
            // Left node
            if (currentIdx % 2 == 0) {
                left = currentHash;
                right = levelDefaults[i];
                hashPairings[i] = levelDefaults[i];
                hashDirections[i] = 0;
                // Right node
            } else {
                left = lastLevelHash[i];
                right = currentHash;
                hashPairings[i] = lastLevelHash[i];
                hashDirections[i] = 1;
            }

            ins[0] = left;
            ins[1] = right;

            uint256 h = hasher.MiMC5Sponge{gas: 150000}(ins, _commitment); // Calcuating parent hash value

            currentHash = h;
            // current leaf node moves up to its parent node
            currentIdx = currentIdx / 2;
        }

        newRoot = currentHash;
        roots[newRoot] = true;
        nextLeafIdex += 1;

        commitments[_commitment] = true;
        emit Deposit(newRoot, hashPairings, hashDirections);
    }

    // function withdraw() external {}
}