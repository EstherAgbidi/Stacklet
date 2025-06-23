;; Stacklet - A decentralized liquidity pool manager for Stacks blockchain
;; Author: Stacklet Team
;; License: MIT

(define-constant ERR_NOT_AUTHORIZED u1)
(define-constant ERR_INSUFFICIENT_BALANCE u2)
(define-constant ERR_POOL_ALREADY_EXISTS u3)
(define-constant ERR_POOL_DOES_NOT_EXIST u4)
(define-constant ERR_ZERO_AMOUNTS u5)

;; Define data maps
(define-map pools
  { pool-id: uint }
  {
    token-x: principal,
    token-y: principal,
    liquidity-token: principal,
    reserves-x: uint,
    reserves-y: uint,
    total-liquidity: uint
  }
)

(define-map user-liquidity
  { pool-id: uint, user: principal }
  { liquidity: uint }
)

;; Store the contract owner
(define-data-var contract-owner principal tx-sender)

;; Get the contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Check if caller is the contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Create a new liquidity pool
(define-public (create-pool (pool-id uint) (token-x principal) (token-y principal) (liquidity-token principal))
  (begin
    (asserts! (is-contract-owner) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-none (map-get? pools { pool-id: pool-id })) (err ERR_POOL_ALREADY_EXISTS))
    
    (map-set pools 
      { pool-id: pool-id }
      {
        token-x: token-x,
        token-y: token-y,
        liquidity-token: liquidity-token,
        reserves-x: u0,
        reserves-y: u0,
        total-liquidity: u0
      }
    )
    (ok true)
  )
)

(define-public (sqrti y)
  (begin
    (define (iterate guess threshold iterations)
      (if (> iterations u0)
          (let ((new-guess (/ (+ guess (/ y guess)) u2)))  ;; Calculate new guess
            (if (< (abs (- guess new-guess)) threshold)  ;; Check if guess is within threshold
                new-guess
                (iterate new-guess threshold (- iterations u1))  ;; Recurse with updated guess
            )
          )
          guess  ;; Return the guess after max iterations
      )
    )
    (iterate y u1 u5)  ;; Start the iteration with initial guess and max iterations
  )
)

;; Add liquidity to a pool
(define-public (add-liquidity (pool-id uint) (amount-x uint) (amount-y uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR_POOL_DOES_NOT_EXIST)))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (liquidity-token (get liquidity-token pool))
    (current-reserves-x (get reserves-x pool))
    (current-reserves-y (get reserves-y pool))
    (current-total-liquidity (get total-liquidity pool))
    (new-liquidity (if (is-eq current-total-liquidity u0)
                      (sqrti (* amount-x amount-y)) ;; This will now use the new iterative function
                      (min 
                        (/ (* amount-x current-total-liquidity) current-reserves-x)
                        (/ (* amount-y current-total-liquidity) current-reserves-y))))
  )
    (asserts! (and (> amount-x u0) (> amount-y u0)) (err ERR_ZERO_AMOUNTS))
    (asserts! (> new-liquidity u0) (err ERR_ZERO_AMOUNTS))
    
    ;; Update the pool reserves
    (map-set pools
      { pool-id: pool-id }
      (merge pool {
        reserves-x: (+ current-reserves-x amount-x),
        reserves-y: (+ current-reserves-y amount-y),
        total-liquidity: (+ current-total-liquidity new-liquidity)
      })
    )
    
    ;; Update user's liquidity
    (let ((current-user-liquidity (default-to { liquidity: u0 } 
                                    (map-get? user-liquidity { pool-id: pool-id, user: tx-sender }))))
      (map-set user-liquidity
        { pool-id: pool-id, user: tx-sender }
        { liquidity: (+ (get liquidity current-user-liquidity) new-liquidity) }
      )
    )
    
    ;; Transfer tokens from user to contract
    ;; In a real implementation, this would involve FT transfers
    ;; For simplicity, we're omitting the actual token transfers
    
    (ok new-liquidity)
  )
)

;; Remove liquidity from a pool
(define-public (remove-liquidity (pool-id uint) (liquidity-amount uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR_POOL_DOES_NOT_EXIST)))
    (user-liq (unwrap! (map-get? user-liquidity { pool-id: pool-id, user: tx-sender }) (err ERR_INSUFFICIENT_BALANCE)))
    (user-liquidity-amount (get liquidity user-liq))
    (pool-total-liquidity (get total-liquidity pool))
    (pool-reserves-x (get reserves-x pool))
    (pool-reserves-y (get reserves-y pool))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (amount-x (/ (* liquidity-amount pool-reserves-x) pool-total-liquidity))
    (amount-y (/ (* liquidity-amount pool-reserves-y) pool-total-liquidity))
  )
    (asserts! (>= user-liquidity-amount liquidity-amount) (err ERR_INSUFFICIENT_BALANCE))
    
    ;; Update the pool reserves
    (map-set pools
      { pool-id: pool-id }
      (merge pool {
        reserves-x: (- pool-reserves-x amount-x),
        reserves-y: (- pool-reserves-y amount-y),
        total-liquidity: (- pool-total-liquidity liquidity-amount)
      })
    )
    
    ;; Update user's liquidity
    (map-set user-liquidity
      { pool-id: pool-id, user: tx-sender }
      { liquidity: (- user-liquidity-amount liquidity-amount) }
    )
    
    ;; Transfer tokens from contract to user
    ;; In a real implementation, this would involve FT transfers
    ;; For simplicity, we're omitting the actual token transfers
    
    (ok (tuple (amount-x amount-x) (amount-y amount-y)))
  )
)

;; Get user liquidity in a pool
(define-read-only (get-user-liquidity (pool-id uint) (user principal))
  (default-to { liquidity: u0 } (map-get? user-liquidity { pool-id: pool-id, user: user }))
)

;; Calculate the output amount for a token swap
(define-read-only (calculate-swap (pool-id uint) (amount-in uint) (is-x-to-y bool))
  (match (map-get? pools { pool-id: pool-id })
    pool (let (
      (reserves-in (if is-x-to-y (get reserves-x pool) (get reserves-y pool)))
      (reserves-out (if is-x-to-y (get reserves-y pool) (get reserves-x pool)))
      (fee-numerator u997)
      (fee-denominator u1000)
      (amount-in-with-fee (* amount-in fee-numerator))
      (numerator (* amount-in-with-fee reserves-out))
      (denominator (+ (* reserves-in fee-denominator) amount-in-with-fee))
    )
      (if (> denominator u0)
        (ok (/ numerator denominator))
        (err ERR_ZERO_AMOUNTS)
      )
    )
    (err ERR_POOL_DOES_NOT_EXIST)
  )
)

;; Swap tokens (x to y)
(define-public (swap-x-for-y (pool-id uint) (amount-in uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR_POOL_DOES_NOT_EXIST)))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    (amount-out (try! (calculate-swap pool-id amount-in true)))
  )
    (asserts! (> amount-out u0) (err ERR_ZERO_AMOUNTS))
    (asserts! (< amount-out reserves-y) (err ERR_INSUFFICIENT_BALANCE))
    
    ;; Update the pool reserves
    (map-set pools
      { pool-id: pool-id }
      (merge pool {
        reserves-x: (+ reserves-x amount-in),
        reserves-y: (- reserves-y amount-out)
      })
    )
    
    ;; In a real implementation, this would involve FT transfers
    ;; For simplicity, we're omitting the actual token transfers
    
    (ok amount-out)
  )
)

;; Swap tokens (y to x)
(define-public (swap-y-for-x (pool-id uint) (amount-in uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR_POOL_DOES_NOT_EXIST)))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    (amount-out (try! (calculate-swap pool-id amount-in false)))
  )
    (asserts! (> amount-out u0) (err ERR_ZERO_AMOUNTS))
    (asserts! (< amount-out reserves-x) (err ERR_INSUFFICIENT_BALANCE))
    
    ;; Update the pool reserves
    (map-set pools
      { pool-id: pool-id }
      (merge pool {
        reserves-x: (- reserves-x amount-out),
        reserves-y: (+ reserves-y amount-in)
      })
    )
    
    ;; In a real implementation, this would involve FT transfers
    ;; For simplicity, we're omitting the actual token transfers
    
    (ok amount-out)
  )
)
