;; Credential Registry Contract
;; Manages credential types, schemas, and templates for the credential management system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-ALREADY-EXISTS (err u2))
(define-constant ERR-INVALID-LENGTH (err u3))
(define-constant ERR-INVALID-INPUT (err u4))
(define-constant ERR-NOT-FOUND (err u5))
(define-constant ERR-SCHEMA-IN-USE (err u6))

;; Data Maps
(define-map credential-types uint 
  {
    name: (string-utf8 50),
    description: (string-utf8 500),
    created-by: principal,
    creation-height: uint,
    status: (string-utf8 20),        ;; "active" or "deprecated"
    version: (string-utf8 20)
  }
)

(define-map schema-definitions uint 
  {
    type-id: uint,
    fields: (list 20 (string-utf8 50)),  ;; List of required field names
    field-types: (list 20 (string-utf8 20)), ;; Corresponding data types
    optional-fields: (list 10 (string-utf8 50)), ;; Optional fields
    metadata: (buff 1024),            ;; Additional schema metadata
    last-updated: uint
  }
)

(define-map type-to-schema {type-id: uint} (list 5 uint))  ;; Maps credential types to their schema versions

;; Data vars for ID tracking
(define-data-var type-counter uint u0)
(define-data-var schema-counter uint u0)

;; Private Functions

(define-private (is-valid-type-id (type-id uint))
  (and
    (> type-id u0)
    (<= type-id (var-get type-counter))
    (is-some (map-get? credential-types type-id))
  )
)

(define-private (is-valid-metadata (metadata (buff 1024)))
  (and
    (>= (len metadata) u0)
    (<= (len metadata) u1024)
  )
)

(define-private (is-valid-optional-fields (fields (list 10 (string-utf8 50))))
  (let ((fields-len (len fields)))
    (and
      (<= fields-len u10)
      (match (element-at fields u0)
        some-val (is-valid-type-name some-val)
        true
      )
    )
  )
)

(define-private (is-valid-type-name (name (string-utf8 50)))
  (let ((len (len name)))
    (and (> len u0) (<= len u50))
  )
)

(define-private (is-valid-description (desc (string-utf8 500)))
  (let ((len (len desc)))
    (and (> len u0) (<= len u500))
  )
)

(define-private (is-valid-version (version (string-utf8 20)))
  (let ((len (len version)))
    (and (> len u0) (<= len u20))
  )
)

(define-private (is-valid-field-list (fields (list 20 (string-utf8 50))))
  (and 
    (> (len fields) u0)
    (<= (len fields) u20)
  )
)

;; Public Functions

(define-public (register-credential-type 
    (name (string-utf8 50))
    (description (string-utf8 500))
    (version (string-utf8 20)))
  (let
    (
      (new-id (+ (var-get type-counter) u1))
    )
    (asserts! (is-valid-type-name name) ERR-INVALID-LENGTH)
    (asserts! (is-valid-description description) ERR-INVALID-LENGTH)
    (asserts! (is-valid-version version) ERR-INVALID-LENGTH)
    
    ;; Only contract owner can register new credential types
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    
    (var-set type-counter new-id)
    (ok (map-set credential-types new-id
      {
        name: name,
        description: description,
        created-by: tx-sender,
        creation-height: block-height,
        status: u"active",
        version: version
      }
    ))
  )
)

(define-public (deprecate-credential-type (type-id uint))
  (let
    ((type-info (unwrap! (map-get? credential-types type-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status type-info) u"active") ERR-INVALID-INPUT)
    
    (ok (map-set credential-types type-id
      (merge type-info { status: u"deprecated" })))
  )
)

(define-public (add-schema 
    (type-id uint)
    (fields (list 20 (string-utf8 50)))
    (field-types (list 20 (string-utf8 20)))
    (optional-fields (list 10 (string-utf8 50)))
    (metadata (buff 1024)))
  (let
    (
      (new-schema-id (+ (var-get schema-counter) u1))
      (type-info (unwrap! (map-get? credential-types type-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-type-id type-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-field-list fields) ERR-INVALID-INPUT)
    (asserts! (is-eq (len fields) (len field-types)) ERR-INVALID-INPUT)
    (asserts! (is-valid-optional-fields optional-fields) ERR-INVALID-INPUT)
    (asserts! (is-valid-metadata metadata) ERR-INVALID-INPUT)
    
    (var-set schema-counter new-schema-id)
    (map-set schema-definitions new-schema-id
      {
        type-id: type-id,
        fields: fields,
        field-types: field-types,
        optional-fields: optional-fields,
        metadata: metadata,
        last-updated: block-height
      }
    )
    
    ;; Update type-to-schema mapping
    (let ((current-schemas (default-to (list ) (map-get? type-to-schema {type-id: type-id}))))
      (ok (map-set type-to-schema 
        {type-id: type-id} 
        (unwrap! (as-max-len? (append current-schemas new-schema-id) u5) ERR-INVALID-INPUT)))
    )
  )
)

;; Read-only Functions

(define-read-only (get-credential-type (type-id uint))
  (map-get? credential-types type-id)
)

(define-read-only (get-schema (schema-id uint))
  (map-get? schema-definitions schema-id)
)

(define-read-only (get-type-schemas (type-id uint))
  (map-get? type-to-schema {type-id: type-id})
)

(define-read-only (get-latest-schema (type-id uint))
  (let ((schemas (unwrap! (map-get? type-to-schema {type-id: type-id}) ERR-NOT-FOUND)))
    (ok (map-get? schema-definitions (unwrap! (element-at schemas (- (len schemas) u1)) ERR-NOT-FOUND)))
  )
)

(define-read-only (is-valid-schema-field 
    (schema-id uint)
    (field-name (string-utf8 50))
    (field-type (string-utf8 20)))
  (let ((schema (unwrap! (map-get? schema-definitions schema-id) ERR-NOT-FOUND)))
    (ok (and
      (is-some (index-of (get fields schema) field-name))
      (is-eq (unwrap! (element-at (get field-types schema) 
        (unwrap! (index-of (get fields schema) field-name) ERR-NOT-FOUND)) ERR-NOT-FOUND)
        field-type)
    ))
  )
)