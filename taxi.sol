pragma solidity  ^0.6.7;

contract TaxiContract {
    
    struct Participant {
        address payable participantAdress;
        uint account;
    }
    
    struct TaxiDriver {
        address payable driverAdress;
        uint account;
        uint salary;
        uint8 approvalState;
        mapping (address => bool) approvedParticipants;
    }
    
    struct ProposedDriver {
        TaxiDriver taxiDriver;
        uint8 approvalState;
        mapping (address => bool) approvedParticipants;
    }
    
    struct ProposedCar {
        uint256 carID;
        uint price;
        uint offerValidTime;
        uint8 approvalState;
        mapping (address => bool) approvedParticipants;
    }
    
    address payable public manager;
    address payable public carDealer;
    address payable[] public participantArray;

    mapping(address => Participant) public participants;
    
    uint256 public contractBalance;
    uint fixedExpenses = 10 ether;
    uint participationFee = 100 ether;
    
    TaxiDriver public taxiDriver;
    uint256 public ownedCar;

    ProposedDriver proposedDriver;
    ProposedCar proposedCar;
    ProposedCar proposedRepurchaseCar;
    
    uint256 startTime;
    uint256 lastSalaryTime;
    uint256 lastDividendTime;
    uint256 lastCarExpensesTime;
    
    event MaintenanceExpenseEvent (
        string eventType,
        address to,
        uint timestamp,
        uint amount
    );
    
    modifier onlyManager {
        require(msg.sender == manager, "Only manager can call this function.");
        _;
    }
    
    modifier onlyCarDealer {
        require(msg.sender == carDealer, "Only carDealer can call this function.");
        _;
    }
    
    modifier onlyDriver {
        require(msg.sender == taxiDriver.driverAdress, "Only driver can call this function.");
        _;
    }
    
    modifier onlyParticipants {
        require(participants[msg.sender].participantAdress == msg.sender, "Only participants can call this function.");
        _;
    }
    
    constructor() public {
        manager = msg.sender;
        contractBalance = 0;
        startTime = now;
        lastDividendTime = now;
        lastCarExpensesTime = now;
    }
    

    
    function join() external payable {
        require(participantArray.length < 9, 'The maximum number of participants has been reached.');
        require(participants[msg.sender].participantAdress != msg.sender, 'This account already participated');
        
        
        contractBalance += participationFee;
    
        participants[msg.sender] = Participant({participantAdress: msg.sender, account: 1 ether});
        participantArray.push(msg.sender);
    }
    
    function setCarDealer(address payable _carDealer) public onlyManager {
        carDealer = _carDealer;
    }

    function carProposeToBusiness(uint256 _carID, uint _price, uint _offerValidTime) public onlyCarDealer {
        proposedCar = ProposedCar({
            carID: _carID,
            price: _price,
            offerValidTime: _offerValidTime,
            approvalState: 0
        });

        for (uint i = 0; i < participantArray.length; i++) {
            proposedCar.approvedParticipants[participantArray[i]] = false;
        }
    }

    function approvePurchaseCar() public onlyParticipants {
        require(proposedCar.approvedParticipants[msg.sender] == false, 'This participant already approved.');

        proposedCar.approvedParticipants[msg.sender] = true;
        proposedCar.approvalState++;
    }

    function purchaseCar() public onlyManager {
        require(now < proposedCar.offerValidTime, 'Offer valid time has been exeeded.');
        require(proposedCar.approvalState > (participantArray.length / 2), 'A majority has not yet been achieved to purchase cars.');
        
        ownedCar = proposedCar.carID;
        
        emit MaintenanceExpenseEvent('Car Purchase', carDealer, now, proposedCar.price);
        carDealer.transfer(proposedCar.price);  
    }

    function repurchaseCarPropose(uint256 _carID, uint _price, uint _offerValidTime) public onlyCarDealer {
        proposedRepurchaseCar = ProposedCar({
            carID: _carID,
            price: _price,
            offerValidTime: _offerValidTime,
            approvalState: 0
        });

        for (uint i = 0; i < participantArray.length; i++) {
            proposedRepurchaseCar.approvedParticipants[participantArray[i]] = false;
        }
    }
    
    function approveSellProposal() public onlyParticipants {
        require(proposedRepurchaseCar.approvedParticipants[msg.sender] == false, 'This participant already approved.');
        
        proposedRepurchaseCar.approvedParticipants[msg.sender] = true;
        proposedRepurchaseCar.approvalState++;
    }
    
    function repurchaseCar() public payable onlyCarDealer {
        require(now < proposedRepurchaseCar.offerValidTime && proposedRepurchaseCar.approvalState > (participantArray.length / 2));
    }
    
    function proposeDriver(address payable _driverAdress, uint _salary) public onlyManager {
        proposedDriver = ProposedDriver({
            taxiDriver: TaxiDriver({
                driverAdress: _driverAdress,
                salary: _salary,
                account: 0,
                approvalState: 0
            }),
            approvalState: 0
        });
        
        for (uint i = 0; i < participantArray.length; i++) {
            proposedDriver.approvedParticipants[participantArray[i]] = false;
        }
    }
    
    function approveDriver() public onlyParticipants {
        require(proposedDriver.approvedParticipants[msg.sender] == false, 'This participant already approved.');

        proposedDriver.approvedParticipants[msg.sender] = true;
        proposedDriver.approvalState++;
    }
    
    function setDriver() public onlyManager {
        require(proposedDriver.approvalState > (participantArray.length / 2), 'A majority has not yet been achieved to set driver.');

        taxiDriver = proposedDriver.taxiDriver;
        lastSalaryTime = now;
    }
    
    function proposeFireDriver() public onlyParticipants {
        require(taxiDriver.approvedParticipants[msg.sender] == false, 'This participant already approved.');

        taxiDriver.approvedParticipants[msg.sender] = true;
        taxiDriver.approvalState++;

        if(taxiDriver.approvalState > participantArray.length/2){
            fireDriver();
        }
    }
    
    function fireDriver() public onlyManager {
        taxiDriver.account += taxiDriver.salary;
        contractBalance -= taxiDriver.salary;
        taxiDriver = TaxiDriver({
                driverAdress: 0x0000000000000000000000000000000000000000,
                salary: 0,
                account: 0,
                approvalState: 0
            });
    }
    
    function leaveJob() public onlyDriver {
        fireDriver();
    }
    
    function getCharge() public payable {
        contractBalance += msg.value;
    }
    
    function paySalary() public onlyManager {
        require(now >= lastSalaryTime + 30 days);
        lastSalaryTime = now;
        
        taxiDriver.account += taxiDriver.salary;
        contractBalance -= taxiDriver.salary;
    }
    
    function getSalary() public onlyDriver {
        require (taxiDriver.account > 0);
        
        uint tmp_account = taxiDriver.account;
        taxiDriver.account = 0;
        
        emit MaintenanceExpenseEvent('Driver Salary', taxiDriver.driverAdress, now, tmp_account);
        
        taxiDriver.driverAdress.transfer(tmp_account);
    }
    
    function carExpenses() public onlyManager {
        require(now >= lastCarExpensesTime + 180 days);
        lastCarExpensesTime = now;
        
        contractBalance -= fixedExpenses;
        
        emit MaintenanceExpenseEvent('Car Expenses', carDealer, now, fixedExpenses);
        
        carDealer.transfer(fixedExpenses);
    }
    
    function payDividend() public onlyManager {
        require(now >= lastDividendTime + 180 days);
        
        carExpenses();
        paySalary();
        
        uint dividend = contractBalance / participantArray.length;
        for (uint i = 0; i < participantArray.length; i++) {
            participants[participantArray[i]].account += dividend;
            contractBalance -= dividend;
        }
        
        lastDividendTime = now;
    }
    
    function getDividend() public onlyParticipants {
        uint tmp_participant_balance = participants[msg.sender].account;
        participants[msg.sender].account = 0;
        
        emit MaintenanceExpenseEvent('Participant Dividend', msg.sender, now, tmp_participant_balance);
        
        msg.sender.transfer(tmp_participant_balance);
    }
    
    fallback() external {
        revert ();
    }
    
    receive() external payable {
        revert ();
    }
}
