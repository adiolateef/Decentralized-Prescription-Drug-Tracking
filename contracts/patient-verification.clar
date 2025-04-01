;; Patient Verification Contract
;; Confirms identity of prescription recipients

(define-constant ERR_UNAUTHORIZED u403)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_EXISTS u409)

;; Admin principal
(define-data-var admin principal tx-sender)

;; Map to store patient information
(define-map patients principal
  {
    id-hash: (buff 32), ;; Hash of patient ID (for privacy)
    is-active: bool,
    registration-date: uint
  }
)

;; Map to store patient consent for data sharing
(define-map patient-consent
  { patient: principal, accessor: principal }
  {
    granted: bool,
    expiration: uint
  }
)

;; Register a new patient
(define-public (register-patient (id-hash (buff 32)))
  (let ((patient tx-sender))
    (asserts! (not (is-registered patient)) (err ERR_ALREADY_EXISTS))

    (map-set patients patient {
      id-hash: id-hash,
      is-active: true,
      registration-date: block-height
    })

    (ok true)
  )
)

;; Check if a patient is registered
(define-read-only (is-registered (patient principal))
  (is-some (map-get? patients patient))
)

;; Check if a patient is active
(define-read-only (is-active-patient (patient principal))
  (match (map-get? patients patient)
    patient-data (get is-active patient-data)
    false
  )
)

;; Grant consent for data access (patient only)
(define-public (grant-consent (accessor principal) (days uint))
  (let
    (
      (patient tx-sender)
      (expiration (+ block-height (* days u144))) ;; ~144 blocks per day
    )

    (asserts! (is-registered patient) (err ERR_NOT_FOUND))

    (map-set patient-consent
      { patient: patient, accessor: accessor }
      {
        granted: true,
        expiration: expiration
      }
    )

    (ok true)
  )
)

;; Revoke consent (patient only)
(define-public (revoke-consent (accessor principal))
  (let ((patient tx-sender))
    (asserts! (is-registered patient) (err ERR_NOT_FOUND))

    (map-set patient-consent
      { patient: patient, accessor: accessor }
      {
        granted: false,
        expiration: u0
      }
    )

    (ok true)
  )
)

;; Check if consent is granted
(define-read-only (has-consent (patient principal) (accessor principal))
  (match (map-get? patient-consent { patient: patient, accessor: accessor })
    consent-data (and
                   (get granted consent-data)
                   (> (get expiration consent-data) block-height)
                 )
    false
  )
)

;; Admin functions
(define-public (deactivate-patient (patient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-registered patient) (err ERR_NOT_FOUND))

    (let ((patient-data (unwrap! (map-get? patients patient) (err ERR_NOT_FOUND))))
      (map-set patients patient (merge patient-data {is-active: false}))
      (ok true)
    )
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
