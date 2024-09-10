// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Proxy_03_2024_Odpowiedzi.sol";
// Import Ownable from OpenZeppelin Contracts library
import "@openzeppelin/contracts/access/Ownable.sol";

interface RootOrganization_PoziomyDostepow {
    // Function to create a new profile
    function createProfile(
        string calldata uniqueId,
        string calldata organization1,
        string calldata organization2,
        string calldata organization3,
        string calldata visibleName,
        string calldata visibleSirname,
        string calldata visibleInfo,
        address RootOrganizacji
    ) external returns(address);

    
    function sprawdzenieProfilu(address account) external view returns (bool);
    function pokazUniqueIdProfiluZAdresuTego(address kontoDoSprawdzenia) external view returns(string memory uniqueIdKonta);
    function hasRole (bytes memory rola,address account) external view returns(bool); 
    function czyZweryfikowanyProfil(address kontoDoSprawdzenia) external view returns(bool);
    function sprawdzProfil(address account,bytes memory rola) external view returns(bool); 
}

interface IMintableToken {
    function mint(address account, uint256 amount) external;
    function BalanceOf(address account) external view returns(uint256 amount);
}

interface IRejestrProfili {
    function rejestrAdminowProfili(address adminPersony) external view returns(address Persona); 
    function czyIstniejeProfil(address kontoDoSprawdzenia) external view returns(bool);
}


contract PeacePollContract is Ownable {

    bytes32 public constant KONSTRUKTORZY = keccak256("KONSTRUKTORZY");

    bytes32 public constant DUPLIKAT = keccak256("DUPLIKAT");
    bytes32 public constant ZBANOWANY = keccak256("ZBANOWANY");

    event EvGlosPoparcia(string UniqueId, address Profil, uint256 iloscGlosowPoparcia);
    event EvGlosSprzeciwu(string UniqueId, address Profil);

    address public addressSystemTokenu = address(0x0);
    address public addressTokenuGlosuPotwierdzonego = address(0x0);
    address public addressTokenuNiezaleznejOrganizacji = address(0x0);
    uint256 public iloscGlosowPoparcia;
    uint256 public iloscGlosowPrzeciw;
    
    address public rejestrProfili;
    address public kontraktOkreslajacyDostepy = address(0x0);// root organizacja Poziomy MPP

    string public opisAnkiety = "n";
    string public dodatkowyOpisAnkiety;
    mapping(uint32  => address) public adresyOpcji;

    mapping(address => uint32) public indeksyOpcji;
    mapping(address => bool) public voted;
    mapping(address => bool) public pobraliTokenZweryfikowanegoGlosu;
    mapping(address => bool) public pobraliTokenGlosuWenatrzOrganizacji;
    mapping(address => bool) public pobraliTokenOpinii;
    mapping(address => bool) public moderatorzy;
    uint public stateOfProject; // 0 - deployed , 1 - initial preparation and testing, 2 - running , 3 - paused
    // indeks opcji
    uint32 public indeksOpcji=1;

    mapping(uint32=>string) public opcjeSpis;
    mapping(uint32=>string) public dokumentyPowiazane;
    uint32 public indeksDokumentu=0;
    address public rootOrganization = address(0x0); // rootOrganization = root organization

    modifier onlyValidState() {
        require(
            (stateOfProject == 3 ) || (stateOfProject == 0 ),
            "Invalid state for the transaction, it is paused"
        );
        _;
    }
    modifier onlyNieGlosujacy() {
        require(
            (voted[msg.sender] != true ),
            "Juz glosowales, You already voted"
        );
        _;
    }
    modifier tylkoModeratorzy() {
        require(moderatorzy[msg.sender] == true ,
            "Nie jestes moderatorem, You are not a moderator / editor"
        );
        _;
    }

    modifier nieZbanowanyDuplikat() {//rootOrganization == address(0x0)||
        require(!RootOrganization_PoziomyDostepow(rootOrganization).sprawdzenieProfilu(address(msg.sender)), "rejestr aktywny ale zostales zbanowany lub korzystasz z duplikatu");
        _;
    }
// sprawdzenie profilu zwraca false jak jest dobry aktywny w systemie profil
    modifier nieZbanowanyDuplikatTxOrigin() {
        address doSprawdzenia=IRejestrProfili(rejestrProfili).rejestrAdminowProfili(tx.origin);
     //   require(!RootOrganization_PoziomyDostepow(rootOrganization).sprawdzenieProfilu(doSprawdzenia), "rejestr aktywny ale zostales zbanowany lub korzystasz z duplikatu");
      // require(!RootOrganization_PoziomyDostepow(rootOrganization).hasRole(abi.encodePacked(DUPLIKAT), doSprawdzenia),"To jest nie aktywny duplikat");
       require(!RootOrganization_PoziomyDostepow(rootOrganization).hasRole(abi.encodePacked(ZBANOWANY), doSprawdzenia),"To jest zbanowany adres");
        _;
    }

    modifier istniejacyProfil(){
    require(IRejestrProfili(rejestrProfili).czyIstniejeProfil(address(msg.sender)),"Twoj Profil nie istnieje w rejestrze profili");
    _;
    }
//  czyIstniejeProfil jest w rejestrze profili
    modifier istniejacyProfilTxOrigin(){
     address doSprawdzenia=IRejestrProfili(rejestrProfili).rejestrAdminowProfili(tx.origin);
    require(IRejestrProfili(rejestrProfili).czyIstniejeProfil(doSprawdzenia),"Twoj Profil nie istnieje w rejestrze profili");
    _;
    }

    modifier zweryfikowanyProfil(){
        require(RootOrganization_PoziomyDostepow(rootOrganization).czyZweryfikowanyProfil(address(msg.sender)),"Twoj Profil nie istnieje w rejestrze profili");
        _;
    }

    modifier zweryfikowanyProfilTxOrigin(){
        address doSprawdzenia=IRejestrProfili(rejestrProfili).rejestrAdminowProfili(tx.origin);
        require(RootOrganization_PoziomyDostepow(rootOrganization).czyZweryfikowanyProfil(doSprawdzenia),"Twoj Profil nie istnieje w rejestrze profili");
        _;
    }

    modifier zweryfikowanyWorganizacjiN(){
        require(RootOrganization_PoziomyDostepow(rootOrganization).czyZweryfikowanyProfil(address(msg.sender)),"Twoj Profil nie istnieje w rejestrze profili");
        _;
        // to bedzie rozbudowane o sprawdzenie roli w organizacji TBD
    }

    modifier onlyProtocolKonstruktors(){

        require(RootOrganization_PoziomyDostepow(rootOrganization).sprawdzProfil(address(msg.sender),abi.encodePacked(KONSTRUKTORZY)),"Twoj Profil nie jest Konstruktorem w rejestrze profili");
        _;
        // to bedzie rozbudowane o sprawdzenie roli w organizacji TBD
    }

    // ok // to potem address  organizacjiWeryfikujacej i glos wewnetrzny
    constructor(address _kontraktOkreslajacyDostepy,address _rejestrProfili) Ownable(address(msg.sender)) {
        // zobaczyć czy fabryka ankiet zostaje ownerem czy trzeba zrobić, jako parametr tworzący
        // dodac role moderator dla ownera raczej
        kontraktOkreslajacyDostepy = _kontraktOkreslajacyDostepy;

    moderatorzy[address(tx.origin)] = true;  // Admin Protokolu

    
    moderatorzy[address(msg.sender)] = true; // fabryka Ankiet
    rejestrProfili=_rejestrProfili;
    }


function ustanowienieModeratorow(address nowyModerator) public onlyProtocolKonstruktors returns(bool)
{

    moderatorzy[nowyModerator] = true;

return true;
}
    function cofniecieModeratorow(address usunModeratora) public onlyProtocolKonstruktors returns(bool)
    {
        moderatorzy[usunModeratora] = false;
        return moderatorzy[usunModeratora];
    }

    function stworzenieOdpowiedzi(string memory opcja) public tylkoModeratorzy returns (address) {
        odpowiedzOpcjaN opcjaOdpowiedzi = new odpowiedzOpcjaN(opcja);
        // zapis do rejestru opcji Odpowiedzi
// rejestr opcji - ocpjaN -indeks opcji
        adresyOpcji[indeksOpcji]=(address(opcjaOdpowiedzi));
        indeksyOpcji[address(opcjaOdpowiedzi)]=indeksOpcji;
        opcjeSpis[indeksOpcji]=opcja;

        indeksOpcji=indeksOpcji+1;


        return(adresyOpcji[indeksOpcji-1]);

}
    function pokazInformacjeOdanejOpcji_showOptionInfoByAdress(address chceInformacjeOopcji) public view returns (string memory) {
        string memory info = opcjeSpis[indeksyOpcji[chceInformacjeOopcji]]; 
        return info;
    }
    function pokazInformacjeOdanejOpcji_showOptionInfoByIndex(uint32 chceInformacjeOopcji) public view returns (string memory) {
        string memory info = opcjeSpis[chceInformacjeOopcji]; 
        return info;
    }

    function pierwszeMojeGlosowanie_myFirstVotingPopieram(
        string memory UniqueId,
        string memory organization1,
        string memory organization2,
        string memory organization3,
        string memory VisibleName,
        string memory VisibleSirname,
        string memory VisibleInfo
    ) public onlyValidState onlyNieGlosujacy {
        // Replace with actual logic
    address nowegoProfilu = RootOrganization_PoziomyDostepow(rootOrganization).createProfile(UniqueId, organization1, organization2, organization3, VisibleName, VisibleSirname, VisibleInfo,kontraktOkreslajacyDostepy);
    
    voted[msg.sender]=true;
    iloscGlosowPoparcia = iloscGlosowPoparcia + 1;


    emit EvGlosPoparcia(UniqueId, nowegoProfilu, iloscGlosowPoparcia);
    }

    function pierwszeMojeGlosowanie_myFirstVotingPrzeciw(
        string memory UniqueId,
        string memory organization1,
        string memory organization2,
        string memory organization3,
        string memory VisibleName,
        string memory VisibleSirname,
        string memory VisibleInfo
    ) public onlyValidState onlyNieGlosujacy{
        // Replace with actual logic
     address nowegoProfilu = RootOrganization_PoziomyDostepow(rootOrganization).createProfile(UniqueId, organization1, organization2, organization3, VisibleName, VisibleSirname, VisibleInfo, kontraktOkreslajacyDostepy);
    
    voted[msg.sender]=true;
    iloscGlosowPrzeciw = iloscGlosowPrzeciw + 1;
    
    emit EvGlosSprzeciwu(UniqueId, nowegoProfilu);  
        // dodaj TIP token
    }



    function setrootOrganization(address ustawRejestr) public tylkoModeratorzy returns(address) {
    rootOrganization = ustawRejestr;
    return rootOrganization;
    }

    function setAddressSystemTokenu(address ustawTokensystemowy) public tylkoModeratorzy returns(address) {
        if(addressSystemTokenu == address(0x0)){ // tu bylo cos nie tak
            addressSystemTokenu = ustawTokensystemowy;
            return addressSystemTokenu;}
       else revert();
       // addressSystemTokenu = ustawTokensystemowy;
       // return addressSystemTokenu;
    }

    function setTokenZweryfikowanych(address ustawTokenuGlosuPotwierdzonego) public tylkoModeratorzy returns(address) {
    if(addressTokenuGlosuPotwierdzonego == address(0x0)){
        addressTokenuGlosuPotwierdzonego = ustawTokenuGlosuPotwierdzonego;
    return addressTokenuGlosuPotwierdzonego;}
        else revert();
    }
    function setTokenuGlosuWewnetrzengo(address TokenuGlosuWewnatrzOrganizacji) public tylkoModeratorzy returns(address) {
        if(addressTokenuNiezaleznejOrganizacji == address(0x0)){
            addressTokenuNiezaleznejOrganizacji = TokenuGlosuWewnatrzOrganizacji;
            return addressTokenuNiezaleznejOrganizacji;}
        else revert();
    }

    function ileGlosowJestPoparciaYesVotes() public view returns(uint256){
        // wylcizenie i raczej na opcjach bilans ...
     return iloscGlosowPoparcia;   
    }

        function ileGlosowJestPrzeciwAgainst() public view returns(uint256){
     return iloscGlosowPrzeciw;   
    }

    function ileGlosowZweryfikowanych_VotesVerified() public view returns(uint256){
     require(addressTokenuGlosuPotwierdzonego!=address(0x0),'Brak aktywnej weryfikacji, Verification and Token was not set');
     return IERC20(addressTokenuGlosuPotwierdzonego).totalSupply();   
    }

    function setStateOfProject(uint setState) public tylkoModeratorzy returns(string memory setedState){
    stateOfProject = setState;
    if(stateOfProject == 0 ) {
     setedState = "deployed"; }
    if(stateOfProject == 1 ) {
     setedState = "initial preparation and testing"; }
    if(stateOfProject == 2 ) {
     setedState = "running"; }
    if(stateOfProject == 3 ) {
     setedState = "paused"; }   
    // 0 - deployed , 1 - initial preparation and testing, 2 - running , 3 - paused
    return setedState;
    }
    function getStringLength(string memory str) public pure returns (uint) {
        bytes memory strBytes = bytes(str);
        return strBytes.length;
    }
    function setOpisAnkiety(string memory opisAnkietyTej) public tylkoModeratorzy {
        if(getStringLength(opisAnkiety)==1){
    opisAnkiety = opisAnkietyTej;}
        else revert("juz nadano opis");
    }
    function dopiszDodatkowyOpisAnkiety(string memory _dodatkowyOpisAnkietyTej) public tylkoModeratorzy {
        dodatkowyOpisAnkiety = _dodatkowyOpisAnkietyTej;
    }
    function dodajDokumentPowiazany(string memory dokumentAdresUrl) public tylkoModeratorzy returns(uint32){
        indeksDokumentu=indeksDokumentu+1;
        dokumentyPowiazane[indeksDokumentu] = dokumentAdresUrl;
        return indeksDokumentu;
    }

    function zobaczDokumentPowiazany(uint32 indeksDokumentuDoWgladu) public view returns(string memory pokaz){

        pokaz=dokumentyPowiazane[indeksDokumentuDoWgladu];
        return pokaz;
    }


// chyba do zmeinienia na dostepy tu ze zweryfikowany
    function pobierzTokenZweryfikowanych() public returns(bool){
    //nieZbanowanyDuplikat istniejacyProfil zweryfikowanyProfil returns(bool){
        // sprawdz czy jest weryfikacja mintu w tokenie - powinna być
       // IMintableToken(addressTokenuGlosuPotwierdzonego).mint(address(tx.origin),1); // tx origin ?
        // weryfikacja mintu ( czy dziala czeck )
     //   require(IMintableToken(addressTokenuGlosuPotwierdzonego).BalanceOf(address(tx.origin))==1);
      //  pobraliTokenZweryfikowanegoGlosu[address(msg.sender)]=true;
        return true;
    }

    function pobierzGlosOpinii() public returns(bool){
        //     nieZbanowanyDuplikat istniejacyProfil returns(bool){
        // sprawdz czy jest weryfikacja mintu w tokenie - powinna być
        IMintableToken(addressSystemTokenu).mint(address(tx.origin),1); // tx origin ?
        // weryfikacja mintu ( czy dziala czeck )
        //require(IMintableToken(addressSystemTokenu).BalanceOf(address(tx.origin))==1);
        pobraliTokenOpinii[address(msg.sender)]=true;
        return true;
    }

    // wewnetrzene glosowanie
    function pobierzTokenZweryfikowanychWewnatrzOrganizacjiN() public nieZbanowanyDuplikat istniejacyProfil zweryfikowanyWorganizacjiN returns(bool){
        address doSprawdzenia=IRejestrProfili(rejestrProfili).rejestrAdminowProfili(tx.origin);
        require(pobraliTokenGlosuWenatrzOrganizacji[doSprawdzenia]!=true,"juz glosowales");
        // sprawdz czy jest weryfikacja mintu w tokenie - powinna być
        IMintableToken(addressTokenuNiezaleznejOrganizacji).mint(address(msg.sender),1); // tx origin ?
        // weryfikacja mintu ( czy dziala czeck )
        require(IMintableToken(addressTokenuNiezaleznejOrganizacji).BalanceOf(address(msg.sender))==1);
        pobraliTokenGlosuWenatrzOrganizacji[doSprawdzenia]=true;
        return true;
    }

// w fabryce ankiet jest :
    /*
    function pobierzTokenGlosuDoAnkiety(uint32 indexAnkiety) public { // to smao musi byc w proofilu
        // tu wstawic kontrole kto moze mintowac i rejestr kto juz zaglosowal
        AnkietaContract(indexAnkiety).pobierzTokenZweryfikowanych; // recheck nazwa
        IMintableToken(tokenAktywnosci).mint(1,msg.sender); // mint tokenu aktywności dla aktywnych

        emit EvPobranoTokenGlosuDoAnkiety(indexAnkeity);
    }

    function pobierzTokenOpiniiWAnkiecie(uint32 indexAnkeity) public { // to smao musi byc  w profilu
        AnkietaContract(indexAnkeity).pobierzGlosOpinii;
        emit EvPobranoTokenOpiniWAnkiecie(indexAnkeity);
    }
    */


    // te opcje sa dostepne dla kazdej oosby w root organizacji ?
    function oddajGlosPoparcia() public nieZbanowanyDuplikat istniejacyProfil returns(bool){
    
    
    voted[msg.sender]=true;
    iloscGlosowPoparcia = iloscGlosowPoparcia + 1;

    string memory UniqueId = RootOrganization_PoziomyDostepow(kontraktOkreslajacyDostepy).pokazUniqueIdProfiluZAdresuTego(address(msg.sender));
   // IMintableToken(addressSystemTokenu).mint(msg.sender,1); // taka opcja jest tylko dla opcji za przeciw, nie ma sensu tokenu mintowac rpzesylanego na opcjeN

    emit EvGlosPoparcia(UniqueId, address(msg.sender), iloscGlosowPoparcia);

    // dodaj TIP token
    return true;
    }

    function oddajGlosPrzeciwu() public nieZbanowanyDuplikat istniejacyProfil returns(bool){
    
    voted[msg.sender]=true;
    iloscGlosowPrzeciw = iloscGlosowPrzeciw + 1;

    string memory UniqueId = RootOrganization_PoziomyDostepow(kontraktOkreslajacyDostepy).pokazUniqueIdProfiluZAdresuTego(address(msg.sender));

    
    emit EvGlosSprzeciwu(UniqueId, address(msg.sender));  
    // dodaj TIP token
    return true;
    }

    

  

    function pobierzTokenGlosuOriginTX6() public istniejacyProfilTxOrigin zweryfikowanyProfilTxOrigin returns(bool){
        address doSprawdzenia=IRejestrProfili(rejestrProfili).rejestrAdminowProfili(tx.origin);  
        require(pobraliTokenZweryfikowanegoGlosu[address(msg.sender)]!=true,"juz glosowales");
        require(pobraliTokenZweryfikowanegoGlosu[tx.origin]!=true,"juz glosowales");
    
        IMintableToken(addressTokenuGlosuPotwierdzonego).mint(address(tx.origin),1); 
        pobraliTokenZweryfikowanegoGlosu[tx.origin]=true;
        pobraliTokenZweryfikowanegoGlosu[doSprawdzenia]=true;                   
        return true;
    }
}
