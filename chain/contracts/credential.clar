;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-ALREADY-REGISTERED (err u2))
(define-constant ERR-INVALID-STATUS (err u3))
(define-constant ERR-EXPIRED (err u4))

;; Data Maps
(define-map verified-issuers principal 
  {
    name: (string-utf8 100),
    verification-date: uint,
    status: (string-utf8 20)  ;; "active" or "suspended"
  }
)

(define-map credentials uint 
  {
    recipient: principal,
    issuer: principal,
    credential-type: (string-utf8 50),
    issue-date: uint,
    expiry-date: uint,
    credential-hash: (buff 32),
    status: (string-utf8 20)  ;; "active" or "revoked"
  }
)

;; Keep track of credential count for unique IDs
(define-data-var credential-counter uint u0)

;; Administrative Functions

(define-public (register-issuer (institution-principal principal) (institution-name (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? verified-issuers institution-principal)) ERR-ALREADY-REGISTERED)
    (ok (map-set verified-issuers institution-principal
      {
        name: institution-name,
        verification-date: block-height,
        status: "active"
      }
    ))
  )
)

(define-public (suspend-issuer (institution-principal principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set verified-issuers institution-principal
      (merge (unwrap! (map-get? verified-issuers institution-principal) ERR-NOT-AUTHORIZED)
        { status: "suspended" })))
  )
)

;; Credential Management Functions

(define-public (issue-credential 
    (recipient-principal principal)
    (credential-type (string-utf8 50))
    (valid-for uint)
    (credential-hash (buff 32)))
  (let
    (
      (issuer tx-sender)
      (new-id (+ (var-get credential-counter) u1))
    )
    (asserts! (is-some (map-get? verified-issuers issuer)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status (unwrap! (map-get? verified-issuers issuer) ERR-NOT-AUTHORIZED)) "active") ERR-INVALID-STATUS)
    (var-set credential-counter new-id)
    (ok (map-set credentials new-id
      {
        recipient: recipient-principal,
        issuer: issuer,
        credential-type: credential-type,
        issue-date: block-height,
        expiry-date: (+ block-height valid-for),
        credential-hash: credential-hash,
        status: "active"
      }
    ))
  )
)

(define-public (revoke-credential (credential-id uint))
  (let
    ((credential (unwrap! (map-get? credentials credential-id) ERR-NOT-AUTHORIZED))
     (issuer tx-sender))
    (asserts! (is-eq (get issuer credential) issuer) ERR-NOT-AUTHORIZED)
    (ok (map-set credentials credential-id
      (merge credential { status: "revoked" })))
  )
)

;; Read-only Functions

(define-read-only (get-credential (credential-id uint))
  (map-get? credentials credential-id)
)

(define-read-only (verify-credential (credential-id uint))
  (let
    ((credential (unwrap! (map-get? credentials credential-id) ERR-NOT-AUTHORIZED)))
    (if (and
      (is-eq (get status credential) "active")
      (< block-height (get expiry-date credential)))
      (ok true)
      (if (>= block-height (get expiry-date credential))
        ERR-EXPIRED
        ERR-INVALID-STATUS)
    )
  )
)

(define-read-only (get-issuer-info (issuer-principal principal))
  (map-get? verified-issuers issuer-principal)
)

(define-read-only (get-credentials-by-recipient (recipient-principal principal))
  (filter map-get? credentials
    (lambda (id)
      (is-eq (get recipient (unwrap! (map-get? credentials id) false)) recipient-principal)
    )
  )
)