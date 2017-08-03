(list 1 (list 2 (list 3 4)))

;; =>
;; (1 (2 (3 4)))

;; The box-and-pointer structure
;; (1 (2 (3 4)))  (2 (3 4))       (3 4)
;;       |           |             |
;;       V           V             V
;;    [x][x]------>[x][x]------>[x][x]------>[x][ ]
;;     |            |            |            |
;;     V            V            V            V
;;    [1]          [2]          [3]          [4]

;; The tree interpretation
;;                        (1 (2 (3 4)))
;;                              |
;;                             / \
;;                            1   (2 (3 4))
;;                                   / \
;;                                  2   (3 4)
;;                                        / \
;;                                       3   4
