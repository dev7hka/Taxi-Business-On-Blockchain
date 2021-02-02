pragma solidity ^0.5.1;

contract TaxiContract{
    
    // Time handles
    uint256 deployTime;
    uint256 lastSalaryReleaseTime;
    uint256 lastCarExpenseTime;
    uint256 lastPayDividendTime;
    
    // Fixed amounts
    uint256 participation_fee = 99 ether;
    uint256 expense = 10 ether;
    
    // manager: creator of contract
    // contract_balance: current total money in contract
    address manager;
    uint256 contract_balance = 0;
    
    //participants indexed from 1 to 9
    mapping (uint => Participant) participants;
    uint countParticipant = 0;
    
    // To provide one vote per person, voting is tracked
    // trackCarVoting: car purchasing or sellling voting is tracked
    // trackDriverVoting: driver hiring voting is tracked
    mapping (address => uint) trackPurchaseVoting;  // if 0 nothing approved, if 1 car purchase proposal approved
    mapping (address => uint) trackRepurchaseVoting;  // if 0 nothing approved, if 1 driver approved
    mapping (address => uint) trackDriverVoting;  // if 0 nothing approved, if 1 car repurchase proposal approved
    
    
    address payable carDealer;
    uint256 carID; 
    DriverProposal driver;       // Current Driver
    CarProposal carProposal;    // Current car proposal of carDealer to sell car
    CarProposal repurchaseProposal;    // Current car proposal of carDealer to buy car
    DriverProposal driverProposal;    // Current driver proposal
    
    struct Participant 
    {
        address payable add;
        uint256 balance;
        bool exists; // to check if exist (because empty mapping is assigned zero)
    }
    struct CarProposal 
    {
        uint256 carID;
        uint256 price;
        uint256 validTime;
        uint state;
    }
    struct DriverProposal
    {
        address payable add;
        uint256 salary;
        uint256 balance;
        uint state;
        bool exists;  // to check if fired or not
    }
    
    modifier onlymanager() 
    {
        require(msg.sender == manager);
        _ ;
    }
    
    event LogJoinMade(address joiner, uint256 amount);
    
    constructor() 
    public 
    {
        manager = msg.sender;
        deployTime = now;
        lastSalaryReleaseTime = now;
        lastCarExpenseTime = now;
        lastPayDividendTime = now;
    }
    function join() 
    public payable 
    {
        require(msg.value >= participation_fee, "You don't have enough money !!!");
        require(countParticipant < 9, "Maximum capacity has been reached !!!");
        
        contract_balance += msg.value;
        emit LogJoinMade(msg.sender, msg.value);
        
        for(uint i=1; i< 10;i++)
        {
            if (participants[i].exists == false)
            {
                participants[i] = Participant(msg.sender, 0 ether, true);
                countParticipant ++;
                return;
            }
        }
    }
    function setCarDealer (
        address payable _address
    ) 
    public onlymanager 
    {
        carDealer = _address;
    }
    
    function carProposeToBusiness(
        uint256 _carID, 
        uint256 _price, 
        uint256 _validTime
    ) 
    public payable 
    {
    require(msg.sender == carDealer, "Only carDealer can propose !!!");
    carProposal = CarProposal(_carID, (_price* 1 ether), now + (_validTime * 1 days), 0);
    clearVoting(0); // every participant's purchase voting is set to zero
    }
    
    function approveProposeToBusiness() 
    public 
    {
        require(personExist(msg.sender) > 0, "This person is not a participant !!!");
        require(trackPurchaseVoting[msg.sender] == 0, "You already voted !!!");  // if not approved yet
    
        carProposal.state +=1;
        trackPurchaseVoting[msg.sender] = 1; 
    
    }
    
    function purchaseCar() 
    public onlymanager payable 
    {
        require(carProposal.state > uint(countParticipant/2), "Not enough person approved !!!"); // more than half of participants
        require(carProposal.validTime >= now, "Offer is no longer valid"); // if propose still valid...
            
        contract_balance -= carProposal.price;
        carDealer.transfer(carProposal.price);
        carID = carProposal.carID;
    
    
    }
    function repurchaseCarPropose(  // carID is not given because there are one car in use (I assumed that way)
        uint256 _price, 
        uint256 _validTime
    ) 
    public 
    {
        require(msg.sender == carDealer, "Only carDealer can propose !!!");
    
        repurchaseProposal = CarProposal(carID, (_price * 1 ether), now + (_validTime * 1 days), 0);
        clearVoting(1);
    }
    
    function approveSellProposal() 
    public 
    {
        require(personExist(msg.sender) > 0, "This person is not a participant !!!");
        require(trackRepurchaseVoting[msg.sender] == 0, "You already voted !!!");  // if not approved yet
    
        repurchaseProposal.state +=1;
        trackRepurchaseVoting[msg.sender] = 1; 
    
    }
    function repurchaseCar() 
    public payable
    {
        require(msg.sender == carDealer, "Only carDealer can approve purchase !!!");
        require(msg.value == repurchaseProposal.price, "CarDealer must provide car price !!!");
        require(repurchaseProposal.state > uint(countParticipant/2), "Not enough approved !!!");  // more than half of participants
        require(repurchaseProposal.validTime >= now, "Propose is no longer valid !!!");  // if propose still valid...
            
        contract_balance += repurchaseProposal.price;  
        carID = 0;
    }
    function proposeDriver(
        address payable _add, 
        uint256 _salary
    ) 
    public onlymanager 
    {
        driverProposal = DriverProposal(_add, (_salary * 1 ether), 0, 0, true);
        clearVoting(2);
    }
    
    function approveDriver() 
    public 
    {
        require(personExist(msg.sender) > 0, "This person is not a participant !!!");
        require(trackDriverVoting[msg.sender] == 0, "You already voted !!!");    // if not approved yet
    
        driverProposal.state +=1;
        trackDriverVoting[msg.sender] = 1; 
    
    }
    function setDriver() 
    public onlymanager 
    {
        require(driverProposal.state > uint(countParticipant/2), "Not enough approve !!!");// more than half of participants
        
        driver = driverProposal;
        lastSalaryReleaseTime = now;
    }
    function fireDriver() 
    public onlymanager 
    {
        require(driver.exists, "This driver is already fired !!!");
        
        contract_balance -= driver.salary;
        driver.add.transfer(driver.salary);
        driver.exists = false;
    }
    function payTaxiCharge() 
    public payable 
    {
        contract_balance += msg.value;
        
    }
    
    function clearVoting(
        uint whichVoting
    )
    
    public payable
    {
        require((msg.sender == carDealer || msg.sender == manager), "Only carDealer can clear !!!");
        for(uint i=1; i < 10; i++)
        {
            if(participants[i].exists == true)
            {
                if (whichVoting == 0)
                    trackPurchaseVoting[participants[i].add] = 0;
                else if (whichVoting == 1)
                    trackRepurchaseVoting[participants[i].add] = 0;
                else if (whichVoting == 2)
                    trackDriverVoting[participants[i].add] = 0;
            }
        }    
    }
    function personExist(address _add) 
    public view returns(uint)
    {
        for(uint i=1; i < 10; i++)
        {
            if(participants[i].exists == true)
                if(participants[i].add == _add)
                    return i;
        }
        return 0;
    }
    
    function releaseSalary() 
    public onlymanager 
    {
        require(driver.exists, "There is no driver !!!");
        require(lastSalaryReleaseTime <= now - 30 days, "You already get paid this month !!!");
        
        contract_balance -= driver.salary;
        driver.balance += driver.salary;
        lastSalaryReleaseTime = now;
       
    }
    function getSalary()
    public 
    {
        require(msg.sender == driver.add, "Only driver can get paid !!!");
        
        driver.add.transfer(driver.balance);
        driver.balance = 0;
    }
    
    function payCarExpenses() 
    public onlymanager  
    {
        require(lastCarExpenseTime <= now - 180 days, "Car expense is already paid in 6 month !!!"); 
        
        contract_balance -= expense;
        carDealer.transfer(expense);
        lastCarExpenseTime = now;
    }
    
    function payDividend() 
    public onlymanager  
    {
        require(lastPayDividendTime <= now - 180 days, "one call per 6 months !!!");
        
        payCarExpenses();
        releaseSalary();
        uint256 profitPerParticipant = contract_balance / countParticipant;
        for(uint i =1; i < 10;i++)
        {
            if(participants[i].exists == true)
                participants[i].balance += profitPerParticipant; 
        } 
        contract_balance = 0;
        lastPayDividendTime = now;
    }
    
    function getDividend() 
    public 
    {
        require(personExist(msg.sender) > 0, "This person is not a participant !!!");
        uint ind = personExist(msg.sender);
        
        participants[ind].add.transfer(participants[ind].balance);
        participants[ind].balance = 0;
        
    }
    
    function() external payable {
         // Do Nothing
    }  
}
