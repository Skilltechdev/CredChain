;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-ALREADY-REGISTERED (err u2))
(define-constant ERR-INVALID-STATUS (err u3))
(define-constant ERR-EXPIRED (err u4))
(define-constant ERR-INVALID-INPUT (err u5))
(define-constant ERR-INVALID-LENGTH (err u6))

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

;; Helper functions for input validation
(define-private (is-valid-string-length (input (string-utf8 100)) (max-len uint))
  (let ((len (len input)))
    (<= len max-len)
  )
)

(define-private (is-valid-status (status (string-utf8 20)))
  (or (is-eq status u"active") 
      (is-eq status u"suspended")
      (is-eq status u"revoked"))
)

(define-private (is-valid-recipient (recipient principal))
  (and 
    (not (is-eq recipient contract-owner))
    (not (is-eq recipient tx-sender))
    (is-ok (principal-destruct? recipient))
  )
)

(define-private (is-valid-credential-hash (hash (buff 32)))
  (and
    (not (is-eq hash 0x))
    (is-eq (len hash) u32)
  )
)

;; Administrative Functions
(define-public (register-issuer (institution-principal principal) (institution-name (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? verified-issuers institution-principal)) ERR-ALREADY-REGISTERED)
    (asserts! (is-valid-string-length institution-name u100) ERR-INVALID-LENGTH)
    (ok (map-set verified-issuers institution-principal
      {
        name: institution-name,
        verification-date: block-height,
        status: u"active"
      }
    ))
  )
)

(define-public (suspend-issuer (institution-principal principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? verified-issuers institution-principal)) ERR-NOT-AUTHORIZED)
    (ok (map-set verified-issuers institution-principal
      (merge (unwrap! (map-get? verified-issuers institution-principal) ERR-NOT-AUTHORIZED)
        { status: u"suspended" })))
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
    (asserts! (is-eq (get status (unwrap! (map-get? verified-issuers issuer) ERR-NOT-AUTHORIZED)) u"active") ERR-INVALID-STATUS)
    (asserts! (is-valid-string-length credential-type u50) ERR-INVALID-LENGTH)
    (asserts! (> valid-for u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-recipient recipient-principal) ERR-INVALID-INPUT)
    (asserts! (is-valid-credential-hash credential-hash) ERR-INVALID-INPUT)
    (var-set credential-counter new-id)
    (ok (map-set credentials new-id
      {
        recipient: recipient-principal,
        issuer: issuer,
        credential-type: credential-type,
        issue-date: block-height,
        expiry-date: (+ block-height valid-for),
        credential-hash: credential-hash,
        status: u"active"
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
      (merge credential { status: u"revoked" })))
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
      (is-eq (get status credential) u"active")
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
  (begin
    (asserts! (is-some (map-get? credentials u1)) ERR-NOT-AUTHORIZED)
    (ok (unwrap-panic (map-get? credentials u1)))
  )
)