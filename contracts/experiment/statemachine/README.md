# State Machines

Most GIF objects have a life cycle defined by a state machine.

For each object type the set of possible states is defined together with its initial state and the set of valid state transitions.

## Object Types without States

* Protocol
* Chains
* Registries (both chain and main registry)

## Object Types with States

* Tokens
* Instances
* Products
* Oracles
* Pools
* Bundles
* Policies
* Claim (non-NFT)
* Payout (non-NFT)

### Simple State Machine

Valid states

* Active (initial state)
* Paused
* Archived (final state)

Valid state transitions:

* Active -> Paused
* Paused -> Active
* Paused -> Archived


Candidate object types for simple state machine

* Token
* Instance
* Product
* Oracle
* Pool

To discuss: 

* Archived is final state
* What mechanism should exist to revert an unintended transition to 'Archived' state. Should there be such a mechanism?
* What mechanism should exist when the NFT of such an object is burned prematurely. Should there be such a mechanism

### Bundle State Machine

Valid states

* Active (initial state)
* Paused
* Expired (implicit state)
* Closed (final state)

Expired is not an explicit state. 
A bundle is expired for block.timestamp >= expiredAt

### Policy State Machine

Valid states

* Applied (initial state)
* Revoked (final state)
* Declined (final state)
* Active
* Expired (implicit state)
* Closed (final state)

Expired is not an explicit state. 
A policy is expired for block.timestamp >= expiredAt

To discuss: 

* Should 'Closed' be less explicit using a closedAt state variable? 
* Or even more lighweight? ie. block.timestamp >= expiredAt and no open claims

Valid state transitions:

* Applied -> Revoked
* Applied -> Declined
* Applied -> Active
* Active -> Closed (needs to be expired)

### Claim State Machine

Valid states
* Applied (initial state)
* Confirmed
* Declined (final state)
* Closed (final state)

Valid state transitions:
* Applied -> Confirmed
* Applied -> Declined
* Confirmed -> Closed

### Payout State Machine

Valid states
* Expected
* PaidOut

Valid state transitions:
* Expected -> PaidOut
