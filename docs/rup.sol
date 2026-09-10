// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title RUP (Revenu Universel Progressif) & CVNU (Curriculum Vitae Numérique Universel)
 * @dev Contrat unifié gérant la collecte de la TVA, l'évaluation des compétences et la distribution sécurisée.
 */
contract RUP is Ownable, ReentrancyGuard {
    
    // ==========================================
    // ÉVÉNEMENTS
    // ==========================================
    event PaymentReceived(address indexed payer, uint256 amount, uint256 totalCollectedTVA);
    event Withdrawal(address indexed citizen, uint256 amount, bytes32 indexed ribHash);

    // ==========================================
    // VARIABLES D'ÉTAT : TRÉSORERIE
    // ==========================================
    uint256 public totalCollectedTVA;
    address public immutable cvnuFundAddress;

    // ==========================================
    // VARIABLES D'ÉTAT : CVNU
    // ==========================================
    struct Competence {
        uint256 level;
        uint256 experience;
        bool isCertified;
    }
    mapping(address => Competence[]) public citizenCV;
    uint256 public constant MIN_RUP = 700;
    uint256 public constant MAX_RUP = 7500;

    // ==========================================
    // VARIABLES D'ÉTAT : SYNCHRONISATION & PAIEMENTS
    // ==========================================
    mapping(address => bytes32) public citizenRIB;
    mapping(address => uint256) public lastPayment;
    uint256 public constant PAYMENT_INTERVAL = 28 days;

    // ==========================================
    // CONSTRUCTEUR
    // ==========================================
    constructor(address _cvnuFundAddress) Ownable(msg.sender) {
        require(_cvnuFundAddress != address(0), "Adresse invalide");
        cvnuFundAddress = _cvnuFundAddress;
    }

    // ==========================================
    // LOGIQUE : TRÉSORERIE (Ex-TVACollector)
    // ==========================================
    
    // Vérifie la liquidité du contrat avant distribution
    function _checkSolvency(uint256 _amount) internal view {
        require(address(this).balance >= _amount, "Solde contrat insuffisant");
    }

    // Réception des fonds (TVA) avec traçabilité publique
    receive() external payable {
        totalCollectedTVA += msg.value;
        emit PaymentReceived(msg.sender, msg.value, totalCollectedTVA);
    }

    // ==========================================
    // LOGIQUE : CVNU (Ex-CVNU.sol)
    // ==========================================
    
    // Ajout d'une compétence au dossier du citoyen
    function updateCompetence(address _citizen, uint256 _level, uint256 _exp, bool _cert) external onlyOwner {
        citizenCV[_citizen].push(Competence(_level, _exp, _cert));
    }

    // Calcul du RUP avec système de paliers discrets (0 à 10)
    function calculateRup(address _citizen) public view returns (uint256) {
        Competence[] memory cv = citizenCV[_citizen];
        if (cv.length == 0) return MIN_RUP;
        
        uint256 totalScore = 0;
        for (uint i = 0; i < cv.length; i++) {
            // Seules les compétences certifiées sont comptabilisées
            if (cv[i].isCertified) {
                totalScore += (cv[i].level * cv[i].experience);
            }
        }
        
        // Détermination du palier (0 à 10 maximum)
        uint256 palier = totalScore / 100;
        if (palier > 10) {
            palier = 10;
        }
        
        // Calcul final : 700 € de base + 680 € par palier franchi
        uint256 finalRup = MIN_RUP + (palier * 680); 
        
        return finalRup > MAX_RUP ? MAX_RUP : finalRup;
    }

    // ==========================================
    // LOGIQUE : SYNCHRONISATION ET DISTRIBUTION
    // ==========================================
    
    // Le citoyen synchronise l'empreinte cryptographique de son RIB
    function synchronizeRIB(bytes32 _ribHash) public {
        citizenRIB[msg.sender] = _ribHash;
    }

    // Distribution sécurisée (anti-réentrance et blocage des doubles versements)
    function distributeFunds(address payable _citizen) public onlyOwner nonReentrant {
        require(citizenRIB[_citizen] != bytes32(0), "RIB non synchronise");
        require(block.timestamp >= lastPayment[_citizen] + PAYMENT_INTERVAL, "Versement mensuel deja effectue");
        
        // 1. Calcul du montant en devise fiat (ex: 750)
        uint256 rupAmountFiat = calculateRup(_citizen);
        require(rupAmountFiat > 0, "Montant invalide");

        // 2. Conversion en Wei (1 token = 1 unite fiat)
        uint256 rupAmountWei = rupAmountFiat * 1 ether;

        // 3. Audit de solvabilité
        _checkSolvency(rupAmountWei);
        
        // 4. Mise à jour de l'état AVANT le transfert (Checks-Effects-Interactions)
        lastPayment[_citizen] = block.timestamp;
        
        // 5. Exécution du transfert
        (bool success, ) = _citizen.call{value: rupAmountWei}("");
        require(success, "Echec du transfert");

        // 6. Émission de l'événement d'audit
        emit Withdrawal(_citizen, rupAmountFiat, citizenRIB[_citizen]);
    }
}