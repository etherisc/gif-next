# Lifecycle

## Release lifecycle

```mermaid
stateDiagram-v2
    [*] --> INITIAL
    INITIAL --> SCHEDULED
    SCHEDULED --> DEPLOYING 
    DEPLOYING --> SCHEDULED
    DEPLOYING --> DEPLOYING
    DEPLOYING --> ACTIVE
    ACTIVE --> SCHEDULED
    ACTIVE --> [*]
    SCHEDULED --> [*]
```

## Component lifecycle

```mermaid
stateDiagram-v2
    [*] --> ACTIVE
    ACTIVE --> PAUSED
    PAUSED --> ACTIVE 
    PAUSED --> ARCHIVED
    ARCHIVED --> [*]
```

## Bundle lifecycle

```mermaid
stateDiagram-v2
    [*] --> ACTIVE
    ACTIVE --> CLOSED 
    CLOSED --> [*]
```

## Policy lifecycle

```mermaid
stateDiagram-v2
    [*] --> APPLIED
    APPLIED --> REVOKED
    APPLIED --> DECLINED 
    APPLIED --> COLLATERALIZED
    COLLATERALIZED --> CLOSED
    CLOSED --> [*]
    REVOKED --> [*]
    DECLINED --> [*]
```

## Premium lifecycle

```mermaid
stateDiagram-v2
    [*] --> EXPECTED
    EXPECTED --> PAID
    PAID --> [*]
```


# Claim lifecycle

```mermaid
stateDiagram-v2
    [*] --> SUBMITTED
    SUBMITTED --> CONFIRMED
    SUBMITTED --> DECLINED
    CONFIRMED --> CLOSED
    CLOSED --> [*]
    DECLINED --> [*]
```

# Payout lifecycle

```mermaid
stateDiagram-v2
    [*] --> EXPECTED
    EXPECTED --> PAID
    EXPECTED --> CANCELLED
    PAID --> [*]
    CANCELLED --> [*]
```

# Risk lifecycle

```mermaid
stateDiagram-v2
    [*] --> ACTIVE
    ACTIVE --> CLOSED
    CLOSED --> [*]
```

# Request lifecycle

```mermaid
stateDiagram-v2
    [*] --> ACTIVE
    ACTIVE --> FULFILLED
    ACTIVE --> FAILED
    ACTIVE --> CANCELLED
    FAILED --> FULFILLED
    FULFILLED --> [*]
    CANCELLED --> [*]
    FAILED --> [*]
```
