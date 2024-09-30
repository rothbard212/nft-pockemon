// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PokeDio is ERC721, Ownable {
    using Counters for Counters.Counter;

    struct Pokemon {
        string name;
        uint level;
        string img;
        uint experience;  // Experiência para aumentar de nível
        uint lastBattle;  // Registro do último tempo de batalha (para cooldown)
    }

    Pokemon[] public pokemons;
    address public gameOwner;
    uint public battleCooldown = 1 days;  // Definindo um cooldown de 24 horas entre batalhas
    Counters.Counter private _pokemonIdCounter;

    event NewPokemonCreated(uint pokemonId, string name, address owner);
    event PokemonEvolved(uint pokemonId, uint newLevel);
    event BattleResult(uint attackerId, uint defenderId, uint attackerNewLevel, uint defenderNewLevel);

    constructor() ERC721("PokeDio", "PKD") {
        gameOwner = msg.sender;
    }

    modifier onlyOwnerOf(uint _pokemonId) {
        require(ownerOf(_pokemonId) == msg.sender, "Apenas o dono pode interagir com este Pokemon");
        _;
    }

    modifier cooldownPassed(uint _pokemonId) {
        require(block.timestamp - pokemons[_pokemonId].lastBattle > battleCooldown, "Aguarde o tempo de cooldown para batalhar novamente");
        _;
    }

    
    function createNewPokemon(string memory _name, address _to, string memory _img) public onlyOwner {
        uint pokemonId = _pokemonIdCounter.current();
        pokemons.push(Pokemon(_name, 1, _img, 0, block.timestamp));  // Inicialmente o Pokemon começa com 0 de experiência
        _safeMint(_to, pokemonId);
        _pokemonIdCounter.increment();
        emit NewPokemonCreated(pokemonId, _name, _to);
    }

    
    function battle(uint _attackingPokemonId, uint _defendingPokemonId)
        public
        onlyOwnerOf(_attackingPokemonId)
        cooldownPassed(_attackingPokemonId)
        cooldownPassed(_defendingPokemonId)
    {
        Pokemon storage attacker = pokemons[_attackingPokemonId];
        Pokemon storage defender = pokemons[_defendingPokemonId];

        if (attacker.level >= defender.level) {
            attacker.experience += 10;
            defender.experience += 5;
        } else {
            attacker.experience += 5;
            defender.experience += 10;
        }

       
        attacker.lastBattle = block.timestamp;
        defender.lastBattle = block.timestamp;

        
        if (attacker.experience >= 100) {
            attacker.level++;
            attacker.experience = 0;
            emit PokemonEvolved(_attackingPokemonId, attacker.level);
        }
        if (defender.experience >= 100) {
            defender.level++;
            defender.experience = 0;
            emit PokemonEvolved(_defendingPokemonId, defender.level);
        }

        emit BattleResult(_attackingPokemonId, _defendingPokemonId, attacker.level, defender.level);
    }

    
    mapping(uint => uint) public pokemonPrices;

    function setPokemonForSale(uint _pokemonId, uint _price) public onlyOwnerOf(_pokemonId) {
        pokemonPrices[_pokemonId] = _price;
    }

    function buyPokemon(uint _pokemonId) public payable {
        uint price = pokemonPrices[_pokemonId];
        address seller = ownerOf(_pokemonId);

        require(price > 0, "Este Pokemon não está à venda");
        require(msg.value == price, "Preço incorreto");

        _transfer(seller, msg.sender, _pokemonId);
        pokemonPrices[_pokemonId] = 0;

        payable(seller).transfer(msg.value);  // Enviar pagamento ao vendedor
    }

    
    function getPokemon(uint _pokemonId) public view returns (string memory name, uint level, string memory img, uint experience) {
        Pokemon storage pokemon = pokemons[_pokemonId];
        return (pokemon.name, pokemon.level, pokemon.img, pokemon.experience);
    }

    
    function setBattleCooldown(uint _time) public onlyOwner {
        battleCooldown = _time;
    }
}
