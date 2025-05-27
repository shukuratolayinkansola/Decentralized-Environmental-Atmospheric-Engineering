;; International Coordination Contract
;; Manages global atmospheric governance

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_COUNTRY_NOT_FOUND (err u401))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u402))
(define-constant ERR_ALREADY_VOTED (err u403))

(define-data-var proposal-counter uint u0)
(define-data-var voting-period uint u1000) ;; blocks

(define-map countries
  { country-code: (string-ascii 3) }
  {
    name: (string-ascii 100),
    representative: principal,
    voting-power: uint,
    active: bool
  }
)

(define-map governance-proposals
  { proposal-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 1000),
    project-id: uint,
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    status: (string-ascii 20)
  }
)

(define-map country-votes
  { proposal-id: uint, country-code: (string-ascii 3) }
  { vote: bool, voting-power: uint, timestamp: uint }
)

(define-public (register-country
  (country-code (string-ascii 3))
  (name (string-ascii 100))
  (representative principal)
  (voting-power uint))
  (begin
    (map-set countries
      { country-code: country-code }
      {
        name: name,
        representative: representative,
        voting-power: voting-power,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (create-governance-proposal
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (project-id uint))
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (map-set governance-proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        project-id: project-id,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        voting-deadline: (+ block-height (var-get voting-period)),
        status: "active"
      }
    )
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal
  (proposal-id uint)
  (country-code (string-ascii 3))
  (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? governance-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (country (unwrap! (map-get? countries { country-code: country-code }) ERR_COUNTRY_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get representative country)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? country-votes { proposal-id: proposal-id, country-code: country-code })) ERR_ALREADY_VOTED)
    (asserts! (< block-height (get voting-deadline proposal)) ERR_UNAUTHORIZED)

    (map-set country-votes
      { proposal-id: proposal-id, country-code: country-code }
      { vote: vote-for, voting-power: (get voting-power country), timestamp: block-height }
    )

    (let ((updated-proposal
      (if vote-for
        (merge proposal { votes-for: (+ (get votes-for proposal) (get voting-power country)) })
        (merge proposal { votes-against: (+ (get votes-against proposal) (get voting-power country)) })
      )))
      (map-set governance-proposals { proposal-id: proposal-id } updated-proposal)
      (ok true)
    )
  )
)

(define-read-only (get-country (country-code (string-ascii 3)))
  (map-get? countries { country-code: country-code })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals { proposal-id: proposal-id })
)

(define-read-only (get-country-vote (proposal-id uint) (country-code (string-ascii 3)))
  (map-get? country-votes { proposal-id: proposal-id, country-code: country-code })
)
