// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract CrowdFunding {
   
    enum Estado  {Abierta, Cancelada, Activa}
   
	address payable public campainManager;
	string public campainName;
	string public campainDescription;
    Estado public  campainEstado;
    uint256 public campainGoal;
	uint256 public participationRate;
    mapping(address => uint256) public participaciones;
    address[] public participantes;
    uint256 public totalParticipaciones;
    uint immutable public CAMPANIN_DUEDATE;

    error NotAuthorizedSpend(uint idproposal, uint votopositivos, uint votostotales);


    modifier only_manager() {
        require(campainManager == msg.sender,"Only Campain manager");
        _;
    }

    //Actividad 
    enum EstadoPeticion {Abierta,Aprobada, Rechazada}

    struct PeticionGasto {
        string detallePeticion;
        EstadoPeticion estado;
        uint importe;
        address payable walletDestinatario;
        uint votosRealizados;
        uint votosPositivos;
        mapping(address => bool) votantes;
    }


    //PeticionGasto[] public peticionesDeGasto;
    mapping (uint => PeticionGasto) public peticionesDeGasto;
    uint totalPeticionesDeGasto;
    event NuevaPeticionGasto(uint ID, uint fechacreacion);
    event ResolucionPeticionGasto(uint ID, bool resolucion);

    
    constructor(string memory _campainName, string memory _campainDesc,uint256 _campainGoal, uint256 _participationRate, uint256 campainduration)  {
        require(_campainGoal > 0 && _participationRate > 0 );
		campainName = _campainName;
		campainDescription = _campainDesc;
		campainManager = payable(msg.sender);
		participationRate = _participationRate;
        campainGoal = _campainGoal;
        campainEstado = Estado.Abierta;
        CAMPANIN_DUEDATE = block.timestamp + campainduration * 1 seconds; //days
    }
    
    function participar() public payable {
        require(msg.value >= participationRate, "Participacion minima no alcanzada" );
        require(campainEstado == Estado.Abierta,"Finalizado plazo participacion");
        if(participaciones[msg.sender] == 0) {  //nuevo participante
            participantes.push(msg.sender);
        }
        uint256 newParticipaciones = msg.value / participationRate;
        participaciones[msg.sender] =  participaciones[msg.sender] + newParticipaciones;
        totalParticipaciones = totalParticipaciones +newParticipaciones;
    }
    receive () external payable {
        participar();
    }
    fallback () external payable {
        participar();
    }
    function getUserParticipaciones(address user) public view returns(uint256) {
        return participaciones[user];
    }
    function getTotalParticipantes() public view returns(uint256) {
        return participantes.length;
    }
    function getParticipantes() public view returns(address[] memory) {
        return participantes;
    }
    function finalizarCampain() public  {
        require(campainEstado == Estado.Abierta,"Campanya no abierta");
        if(msg.sender != campainManager) {
            require(block.timestamp >=  CAMPANIN_DUEDATE, "Campain is not over yet");
        }

        if(campainGoal <= address(this).balance) {
            campainEstado = Estado.Activa;
        }else {
            campainEstado = Estado.Cancelada;
        }
    }
   

    function withdrawCanceledCampain() public {
        require(participaciones[msg.sender] > 0, "fondos retirados");
        require(campainEstado == Estado.Cancelada,"Campanya no cancelada");
        uint256 aportacionUsuario = participaciones[msg.sender] * participationRate;
        participaciones[msg.sender] = 0;
        payable(msg.sender).transfer(aportacionUsuario);
    }

   
    function test_contractBalance() public view returns (uint256) {
       // require (campainEstado == Estado.Activa,"Campanya no activa");
        return address(this).balance;
    }

     /* Actividad
    function adminGetFunds() public only_manager {
        campainManager.transfer(address(this).balance);
    }*/
    
     function	crearPeticionDeGasto(string memory _detalle, uint _importe, address payable _destinatario) public only_manager {
	    require(_importe <= address(this).balance, "saldo insuficiente");
	    require(_destinatario != address(0));

        //Nota: no podemos crear peticionesDeGasto como una lista si tenemos un mapping interno. alternativamente tenemos que gestionarlo como un mapping
        //daria error:  Struct containing a (nested) mapping cannot be constructed.
        //ver: https://ethereum.stackexchange.com/questions/87451/solidity-error-struct-containing-a-nested-mapping-cannot-be-constructed

        PeticionGasto storage peticion = peticionesDeGasto[totalPeticionesDeGasto];
        peticion.detallePeticion =_detalle; 
        peticion.estado = EstadoPeticion.Abierta;
        peticion.importe = _importe;
        peticion.walletDestinatario = _destinatario;
       // peticion.votosRealizados = 0;
       // peticion.votosPositivos = 0;
        
	    emit NuevaPeticionGasto(totalPeticionesDeGasto, block.timestamp);
        totalPeticionesDeGasto++;
	}
    function getNPeticionesDeGasto() public view returns (uint) {
        return totalPeticionesDeGasto;
    }
    function getPeticionesGastoAbiertas() public view returns(uint[] memory) {
        uint[] memory peticionesGastoAbiertasAux = new uint[](totalPeticionesDeGasto);
        uint cantidad = 0;

        for(uint i = 0; i < totalPeticionesDeGasto; i++){
            if(peticionesDeGasto[i].estado == EstadoPeticion.Abierta) {
                peticionesGastoAbiertasAux[cantidad] = i;
                cantidad++;
            }
        }
            //ejemplo [0,1,2,3,4] y peticiones 0,1 y 4 abiertas --> [0,1,4,0,0] --> esperado [0,1,4]
        uint[] memory peticionesGastoAbiertas  = new uint[](cantidad);
        for(uint i = 0; i < cantidad; i++){
            peticionesGastoAbiertas[i] = peticionesGastoAbiertasAux[i];
        }

        return peticionesGastoAbiertas;
    }
    function getDetailPeticionGastobyId(uint index) public  view returns(string memory,uint, bool){
        require(index < totalPeticionesDeGasto, "peticion inexistentre" );
        bool aprobada = false;

        if(peticionesDeGasto[index].estado == EstadoPeticion.Aprobada) {aprobada = true; }

        PeticionGasto storage pt = peticionesDeGasto[index];

        return (pt.detallePeticion,pt.importe,aprobada );
    }


    function votarPeticionGasto(uint IDpeticion, bool aprobar) public {
       /* TODO ACtividad*/
        require(participaciones[msg.sender] > 0, "No tienes participaciones");
        require(IDpeticion >= 0 && IDpeticion <= totalPeticionesDeGasto , "peticion inexistentre" );
        uint pesoVoto = participaciones[msg.sender];
        require(pesoVoto > 0, "no tienes derecho a voto");
        peticionesDeGasto[IDpeticion].votosRealizados += pesoVoto;

        if(aprobar == true){
            

            peticionesDeGasto[IDpeticion].votosPositivos += pesoVoto;

        }


    }


    function resolverPeticion(uint index) public only_manager {

    /* TODO Actividad */
    require(peticionesDeGasto[index].estado == EstadoPeticion.Abierta,"Peticion gasto cerrada");

    require(index >= 0 && index <= totalPeticionesDeGasto , "peticion inexistentre" );
    if(peticionesDeGasto[index].votosPositivos >= (peticionesDeGasto[index].votosRealizados)/2){

        require(peticionesDeGasto[index].importe <= address(this).balance, "insuficientes fondos");
        
        peticionesDeGasto[index].estado = EstadoPeticion.Aprobada;

        payable(peticionesDeGasto[index].walletDestinatario).transfer(peticionesDeGasto[index].importe);

        emit ResolucionPeticionGasto(index,true);


    } else{

        peticionesDeGasto[index].estado = EstadoPeticion.Rechazada;
        emit ResolucionPeticionGasto(index,false);
        revert NotAuthorizedSpend(index,peticionesDeGasto[index].votosPositivos, peticionesDeGasto[index].votosRealizados );     
    }


    }

}
