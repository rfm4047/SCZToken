// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Interfaz mínima para un oráculo de crédito.
interface ICreditOracle {
    function getCreditScore(address user) external view returns (uint256);
}

/**
 * @title SCZToken
 * @dev Contrato ERC20 extendido que incorpora funcionalidades de mercado de crédito,
 * tokenización de inmuebles, gobernanza, KYC/AML, refinanciamiento y evaluación crediticia vía oráculo.
 *
 * Se agrupan los parámetros del constructor en dos arrays para evitar errores de "Stack too deep".
 *
 * - addresses: array de 5 elementos con:
 *    [0] preSaleWallet
 *    [1] liquidityWallet
 *    [2] teamWallet
 *    [3] marketingWallet
 *    [4] reserveWallet
 *
 * - params: array de 7 elementos con:
 *    [0] softCap
 *    [1] hardCap
 *    [2] tokenPrice
 *    [3] preSaleStart
 *    [4] preSaleEnd
 *    [5] minPurchase
 *    [6] maxPurchase
 */
contract SCZToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;

    // Direcciones de distribución
    address public preSaleWallet;
    address public liquidityWallet;
    address public teamWallet;
    address public marketingWallet;
    address public reserveWallet;

    // Parámetros de la preventa
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public tokenPrice;
    uint256 public preSaleStart;
    uint256 public preSaleEnd;
    uint256 public minPurchase;
    uint256 public maxPurchase;

    // Distribución de fondos (porcentajes, para fines ilustrativos)
    uint8 public liquidityPercentage = 50;
    uint8 public developmentPercentage = 20;
    uint8 public marketingPercentage = 15;
    uint8 public teamPercentage = 10;
    uint8 public reservePercentage = 5;

    // Módulo de Préstamos y Mercado de Crédito
    struct Loan {
        uint256 amount;
        uint256 interestRate; // tasa variable (porcentaje)
        uint256 dueDate;
        bool collateralProvided;
        bool repaid;
        address borrower;
        uint256 amountPaid; // monto pagado parcial o total
    }
    mapping(uint256 => Loan) public loans;
    uint256 public nextLoanId;

    // Mapeo para almacenar valores de propiedades (simulado)
    mapping(uint256 => uint256) public propertyValues;
    // Mapeo para almacenar la fracción (en porcentaje, 0 a 100) que posee cada usuario de un inmueble
    mapping(uint256 => mapping(address => uint256)) public propertyFractions;

    // Módulo de Gobernanza
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        bool executed;
    }
    mapping(uint256 => Proposal) public proposals;
    uint256 public nextProposalId;
    mapping(address => bool) public hasVoted; // cada dirección vota una vez

    // Registro de usuarios verificados (KYC/AML)
    mapping(address => bool) public isKYCVerified;

    // NUEVO: Variables para integración con oráculo de crédito
    ICreditOracle public creditOracle;
    uint256 public creditThreshold; // Umbral para considerar excelente historial crediticio

    // Eventos
    event LoanRequested(uint256 loanId, address borrower, uint256 amount, bool collateralProvided);
    event LoanRepaid(uint256 loanId, address borrower);
    event LoanLiquidated(uint256 loanId, address borrower);
    event LoanRefinanced(uint256 loanId, address borrower, uint256 newDueDate, uint256 newInterestRate);
    event ProposalCreated(uint256 proposalId, string description);
    event Voted(uint256 proposalId, address voter, uint256 voteCount);
    event IncomeDistributed(uint256 amount);
    event FractionBought(uint256 propertyId, address buyer, uint256 fraction, uint256 paidAmount);

    /**
     * @dev Constructor que recibe dos arrays para evitar "Stack too deep".
     * @param addresses Array de direcciones (5 elementos: preSaleWallet, liquidityWallet, teamWallet, marketingWallet, reserveWallet).
     * @param params Array de parámetros (7 elementos: softCap, hardCap, tokenPrice, preSaleStart, preSaleEnd, minPurchase, maxPurchase).
     */
    constructor(
        address[] memory addresses,
        uint256[] memory params
    ) ERC20("SCZ Token", "SCZ") Ownable(msg.sender) {
        require(addresses.length == 5, "Se requieren 5 direcciones");
        require(params.length == 7, "Se requieren 7 parametros");

        preSaleWallet = addresses[0];
        liquidityWallet = addresses[1];
        teamWallet = addresses[2];
        marketingWallet = addresses[3];
        reserveWallet = addresses[4];

        softCap = params[0];
        hardCap = params[1];
        tokenPrice = params[2];
        preSaleStart = params[3];
        preSaleEnd = params[4];
        minPurchase = params[5];
        maxPurchase = params[6];

        // Distribución de tokens según porcentajes:
        _mint(preSaleWallet, (TOTAL_SUPPLY * 50) / 100);    // Preventa: 50%
        _mint(liquidityWallet, (TOTAL_SUPPLY * 20) / 100);    // Liquidez: 20%
        _mint(teamWallet, (TOTAL_SUPPLY * 15) / 100);         // Equipo/creador: 15%
        _mint(marketingWallet, (TOTAL_SUPPLY * 10) / 100);    // Marketing: 10%
        _mint(reserveWallet, (TOTAL_SUPPLY * 5) / 100);       // Reserva: 5%
    }

    // -------------------------------
    // Funciones de Préstamos y Mercado de Crédito
    // -------------------------------
    function requestLoan(uint256 amount, bool withCollateral) public returns (uint256 loanId) {
        require(isKYCVerified[msg.sender], "KYC not verified");

        uint256 interestRate = withCollateral ? 5 : 10;
        uint256 dueDate = block.timestamp + 30 days;

        loans[nextLoanId] = Loan({
            amount: amount,
            interestRate: interestRate,
            dueDate: dueDate,
            collateralProvided: withCollateral,
            repaid: false,
            borrower: msg.sender,
            amountPaid: 0
        });

        emit LoanRequested(nextLoanId, msg.sender, amount, withCollateral);
        nextLoanId++;
        return nextLoanId - 1;
    }

    function repayLoan(uint256 loanId) public {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not borrower");
        require(!loan.repaid, "Loan already repaid");
        loan.amountPaid = loan.amount;
        loan.repaid = true;
        emit LoanRepaid(loanId, msg.sender);
    }

    // Permite pagos parciales para el préstamo
    function partialRepayLoan(uint256 loanId, uint256 payment) external {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not borrower");
        require(!loan.repaid, "Loan already repaid");
        loan.amountPaid += payment;
        if (loan.amountPaid >= loan.amount) {
            loan.repaid = true;
            emit LoanRepaid(loanId, msg.sender);
        }
    }

    // Permite refinanciar el préstamo si se ha pagado al menos el 75% sin retrasos
    function refinanceLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not borrower");
        require(!loan.repaid, "Loan already repaid");
        require(loan.amountPaid >= (loan.amount * 75) / 100, "Insufficient repayment for refinancing");
        require(block.timestamp <= loan.dueDate, "Loan is overdue");

        loan.dueDate = block.timestamp + 30 days;
        if (loan.interestRate > 2) {
            loan.interestRate -= 2;
        }
        emit LoanRefinanced(loanId, loan.borrower, loan.dueDate, loan.interestRate);
    }

    // -------------------------------
    // Funciones de Oráculo y Colateralización
    // -------------------------------
    function updatePropertyValue(uint256 propertyId, uint256 newValue) external onlyOwner {
        propertyValues[propertyId] = newValue;
    }

    // -------------------------------
    // Funciones para tokenización y fraccionalización de inmuebles
    // -------------------------------
    /**
     * @dev Permite a un usuario comprar una fracción de un inmueble.
     * Se requiere que el inmueble tenga un valor asignado.
     * El precio se calcula como: (valor total del inmueble / 100) * fraction.
     * Se debe enviar como pago el monto correspondiente en msg.value.
     */
    function buyFraction(uint256 propertyId, uint256 fraction) external payable {
        require(fraction > 0 && fraction <= 100, "Invalid fraction");
        uint256 propertyValue = propertyValues[propertyId];
        require(propertyValue > 0, "Property not valued");

        uint256 requiredPayment = (propertyValue * fraction) / 100;
        require(msg.value >= requiredPayment, "Insufficient payment");

        // Se registra la fracción comprada
        propertyFractions[propertyId][msg.sender] += fraction;
        emit FractionBought(propertyId, msg.sender, fraction, msg.value);
    }

    // -------------------------------
    // Funciones de Gobernanza
    // -------------------------------
    function createProposal(string calldata description) external onlyOwner {
        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            description: description,
            voteCount: 0,
            executed: false
        });
        emit ProposalCreated(nextProposalId, description);
        nextProposalId++;
    }

    function voteProposal(uint256 proposalId) external {
        require(!hasVoted[msg.sender], "Already voted");
        Proposal storage proposal = proposals[proposalId];
        proposal.voteCount += 1;
        hasVoted[msg.sender] = true;
        emit Voted(proposalId, msg.sender, proposal.voteCount);
    }

    // -------------------------------
    // Distribución de Ingresos
    // -------------------------------
    function distributeIncome(uint256 incomeAmount) external onlyOwner {
        emit IncomeDistributed(incomeAmount);
    }

    // -------------------------------
    // Funciones KYC/AML
    // -------------------------------
    function verifyKYC(address user) external onlyOwner {
        isKYCVerified[user] = true;
    }

    function revokeKYC(address user) external onlyOwner {
        isKYCVerified[user] = false;
    }

    // -------------------------------
    // Funciones de Evaluación y Solicitud de Crédito
    // -------------------------------

    /**
     * @dev Configura el oráculo de crédito y el umbral mínimo de puntaje.
     * Solo el owner puede llamar a esta función.
     */
    function setCreditOracle(address _oracle, uint256 _threshold) external onlyOwner {
        creditOracle = ICreditOracle(_oracle);
        creditThreshold = _threshold;
    }

    /**
     * @dev Función interna que verifica si el usuario tiene excelente historial crediticio.
     * Se consulta al oráculo de crédito y se compara con el umbral establecido.
     * Si no hay oráculo configurado, se recurre al criterio de KYC.
     */
    function hasExcellentCreditHistory(address user) internal view returns (bool) {
        if (address(creditOracle) != address(0)) {
            uint256 score = creditOracle.getCreditScore(user);
            return score >= creditThreshold;
        }
        return isKYCVerified[user];
    }

    /**
     * @dev Permite solicitar crédito utilizando un inmueble tokenizado como colateral.
     * Se requiere que el usuario posea una fracción del inmueble y tenga excelente historial crediticio,
     * evaluado mediante el oráculo de crédito (o mediante KYC como fallback).
     */
    function requestCreditWithRealEstate(uint256 propertyId, uint256 creditAmount) external returns (uint256) {
        uint256 propertyValue = propertyValues[propertyId];
        require(propertyValue > 0, "Property not valued");
        require(propertyFractions[propertyId][msg.sender] > 0, "No fraction owned");
        require(hasExcellentCreditHistory(msg.sender), "Credit history not excellent");
        uint256 maxCredit = (propertyValue * propertyFractions[propertyId][msg.sender]) / 100;
        require(creditAmount <= maxCredit, "Credit exceeds limit");
        return requestLoan(creditAmount, true);
    }

    /**
     * @dev Permite solicitar crédito sin colateral.
     */
    function requestCreditWithoutCollateral(uint256 creditAmount) external returns (uint256) {
        return requestLoan(creditAmount, false);
    }

    /**
     * @dev Calcula la tasa de interés para un préstamo específico.
     */
    function calculateInterest(uint256 loanId) external view returns (uint256) {
        Loan memory loan = loans[loanId];
        return (loan.amount * loan.interestRate) / 100;
    }
    // Función para acuñar tokens adicionales (solo el owner puede llamarla)
    function mint(address to, uint256 amount) external onlyOwner {
    _mint(to, amount);
    }

    // Funciones adicionales para mercados secundarios y fraccionalización (a implementar)
}
