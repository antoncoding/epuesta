# Epuesta

Epuesta is a decentralized betting broker framework built with ChainLink.

![chainlinkImg](https://blog.chain.link/content/images/size/w2000/2019/07/Growing-Chainlink--1-.png)

Everyone can create a new contract with our framework on Ethereum as a broker for a specific match, you can customize your need and offer different deals with the contract.

The finality of a match is provided by Chainlink nodes in an decentralized manner, and result is distributed fairly with the contract.

## Integration for Node Operators

### Add New Bridge - apifootball

Currently using [Apifootball](https://apifootball.com/documentation/) as our data source.
A sample RESTful API external adopter can be found at [this repo](https://github.com/antoncoding/apifootball-adopter).

Run it yourself or use our heroku server, then create a new **apifootball** Bridge with the adopter url.

Our adopter is deployed at:

```url
https://apifootball-adopter.herokuapp.com/
```

![New Bridge](https://i.imgur.com/Rk7AIrR.png)

### Add New Jobs

With our current design, a chainlink node has to add two jobs in order to be capable of being Epuesta data source oracle.

The job specs can be found in `jobs/`

![new job](https://i.imgur.com/2YcYTgh.png)

## Contract Creator
