```mermaid
erDiagram 
    Instance ||--o{ Product : ""
    Product ||--o{ Risk : ""
    Product ||--o{ Policy : ""
    Risk ||--o{ Policy : ""
    Policy ||--o{ Claim : ""
    Claim ||--o{ Payout : ""
```