;;;; By Nikodemus Siivola <nikodemus@random-state.net>, 2009.
;;;;
;;;; Permission is hereby granted, free of charge, to any person
;;;; obtaining a copy of this software and associated documentation files
;;;; (the "Software"), to deal in the Software without restriction,
;;;; including without limitation the rights to use, copy, modify, merge,
;;;; publish, distribute, sublicense, and/or sell copies of the Software,
;;;; and to permit persons to whom the Software is furnished to do so,
;;;; subject to the following conditions:
;;;;
;;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;;;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;;;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;;;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;;;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(in-package :sb-cga)

;;;; ACCESSORS

(declaim (ftype (sfunction (matrix (integer 0 3) (integer 0 3)) single-float) mref)
         (inline mref))
(defun mref (matrix row column)
  "Return value in the specificed ROW and COLUMN in MATRIX."
  (aref matrix (+ row (* column 4))))

(declaim (inline (setf mref)))
(defun (setf mref) (value matrix row column)
  (setf (aref matrix (+ row (* column 4))) value))

;;; PRETTY-PRINTING

(defun pprint-matrix (stream matrix)
  (pprint-logical-block (stream nil)
    (print-unreadable-object (matrix stream :type nil :identity nil)
      (dotimes (i 4)
        (format stream "[~s, ~s, ~s, ~s]"
                (mref matrix i 0)
                (mref matrix i 1)
                (mref matrix i 2)
                (mref matrix i 3))
        (unless (= 3 i)
          (pprint-newline :mandatory stream))))))
(set-pprint-dispatch 'matrix 'pprint-matrix)

;;;; PREDICATES

(declaim (ftype (sfunction (t) boolean))
         (inline matrixp))
(defun matrixp (object)
  "Return true of OBJECT is a matrix."
  (typep object 'matrix))

;;;; COMPARISON

(declaim (ftype (sfunction (matrix matrix) boolean) matrix=))
(defun matrix= (a b)
  "Return true if MATRIX A is elementwise equal to MATRIX B."
  (dotimes (i 16 t)
    (unless (= (aref a i) (aref b i))
      (return nil))))

;;;; CONSTRUCTORS

(declaim (ftype (sfunction (single-float single-float single-float single-float
                            single-float single-float single-float single-float
                            single-float single-float single-float single-float
                            single-float single-float single-float single-float)
                           matrix)
                matrix)
         (inline matrix))
(defun matrix (m11 m12 m13 m14
               m21 m22 m23 m24
               m31 m32 m33 m34
               m41 m42 m43 m44)
  "Construct MATRIX with the given elements (arguments are provided in row
major order.)"
  (make-array 16
              :element-type 'single-float
              :initial-contents (list m11 m21 m31 m41
                                      m12 m22 m32 m42
                                      m13 m23 m33 m43
                                      m14 m24 m34 m44)))

(declaim (ftype (sfunction () matrix) zero-matrix)
         (inline zero-matrix))
(defun zero-matrix ()
  "Construct a zero matrix."
  (make-array 16 :element-type 'single-float))

(declaim (ftype (sfunction () matrix) identity-matrix))
(defun identity-matrix ()
  "Construct an identity matrix."
  (matrix 1.0 0.0 0.0 0.0
          0.0 1.0 0.0 0.0
          0.0 0.0 1.0 0.0
          0.0 0.0 0.0 1.0))

;;;; MATRIX MULTIPLICATION

(declaim (ftype (sfunction (vec matrix) vec) transform-vec)
         (inline transform-vec))
(defun transform-vec (vec matrix)
  "Apply transformation MATRIX to VEC, return result as a freshly allocated VEC."
  (%transform-vec (alloc-vec) vec matrix))

(declaim (ftype (sfunction (&rest matrix) matrix) matrix*))
(defun matrix* (&rest matrices)
  "Multiply MATRICES, return result as a freshly allocated MATRIX."
  (if matrices
      (let ((result (replace (zero-matrix) (the matrix (car matrices)))))
        (dolist (matrix (cdr matrices))
          (dotimes (i 4)
            (dotimes (j 4)
              (setf (mref result i j)
                    (loop for k below 4
                          summing (* (mref result i k) (mref matrix k j)))))))
        result)
      (identity-matrix)))

;;;; TRANSFORMATIONS

(declaim (ftype (sfunction (single-float single-float single-float) matrix) translate*))
(defun translate* (x y z)
  "Construct a translation matrix from translation factors X, Y and Z."
  (matrix 1.0 0.0 0.0 x
          0.0 1.0 0.0 y
          0.0 0.0 1.0 z
          0.0 0.0 0.0 1.0))

(declaim (ftype (sfunction (vec) matrix) translate))
(defun translate (vec)
  "Construct a translation matrix using first three elements of VEC as the
translation factors."
  (translate* (aref vec 0) (aref vec 1) (aref vec 2)))

(declaim (ftype (sfunction (single-float single-float single-float) matrix) scale*))
(defun scale* (x y z)
  "Construct a scaling matrix from scaling factors X, Y, and Z."
  (matrix x    0.0  0.0  0.0
          0.0  y    0.0  0.0
          0.0  0.0  z    0.0
          0.0  0.0  0.0  1.0))

(declaim (ftype (sfunction (vec) matrix) scale))
(defun scale (vec)
  "Construct a scaling matrix using first threee elements of VEC as the
scaling factors."
  (scale* (aref vec 0) (aref vec 1) (aref vec 2)))

(declaim (ftype (sfunction (single-float single-float) matrix) rotate))
(defun rotate* (x y z)
  "Construct a rotation matrix from rotation factors X, Y, Z."
  (let (rotations)
    (unless (= 0.0 x)
      (let ((c (cos x))
            (s (sin x)))
        (push (matrix 1.0   0.0   0.0    0.0
                      0.0   c     (- s)  0.0
                      0.0   s     c      0.0
                      0.0   0.0   0.0    1.0)
              rotations)))
    (unless (= 0.0 y)
      (let ((c (cos y))
            (s (sin y)))
        (push (matrix c     0.0   s      0.0
                      0.0   1.0   0.0    0.0
                      (- s) 0.0   c      0.0
                      0.0   0.0   0.0    1.0)
              rotations)))
    (unless (= 0.0 z)
      (let ((c (cos z))
            (s (sin z)))
        (push (matrix c     (- s) 0.0    0.0
                      s     c     0.0    0.0
                      0.0   0.0   1.0    0.0
                      0.0   0.0   0.0    1.0)
              rotations)))
    (apply #'matrix* rotations)))

(declaim (ftype (sfunction (vec) matrix) rotate))
(defun rotate (vec)
  "Construct a rotation matrix using first three elements of VEC as the
rotation factors."
  (rotate* (aref vec 0) (aref vec 1) (aref vec 2)))

(declaim (ftype (sfunction (vec single-float) matrix) rotate-around))
(defun rotate-around (a radians)
  "Construct a rotation matrix that rotates by RADIANS around VEC A. 4th
element of A is ignored."
  (let ((c (cos radians))
	(s (sin radians))
	(g (- 1.0 (cos radians))))
    (let* ((x (aref a 0))
           (y (aref a 1))
           (z (aref a 2))
           (gxx (* g x x)) (gxy (* g x y)) (gxz (* g x z))
           (gyy (* g y y)) (gyz (* g y z)) (gzz (* g z z)))
      (matrix
       (+ gxx c)        (- gxy (* s z))  (+ gxz (* s y)) 0.0
       (+ gxy (* s z))  (+ gyy c)        (- gyz (* s x)) 0.0
       (- gxz (* s y))  (+ gyz (* s x))  (+ gzz c)       0.0
       0.0              0.0              0.0             1.0))))

(declaim (ftype (sfunction (vec vec) matrix) reorient))
(defun reorient (a b)
  "Construct a transformation matrix to reorient A with B."
  (let ((na (normalize a))
	(nb (normalize b)))
    ;; FIXME: Use a looser equality here, maybe.
    (if (vec= na nb)
	(identity-matrix)
	(rotate-around (normalize (cross-product na nb))
		       (acos (dot-product na nb))))))

(declaim (inline square))
(defun square (x) (* x x))

;;; FIXME: Proper inversion, not just this single case, maybe?
(declaim (ftype (sfunction (matrix) matrix) inverse-matrix))
(defun inverse-matrix (matrix)
  "Inverse of an orthogonal affine 4x4 matrix. The argument is not checked
for orthogonality or affinness."
  (declare (type matrix matrix))
  (let ((inverse (zero-matrix)))
    ;; transpose and invert scales for upper 3x3
    (dotimes (i 3)
      (let ((scale (/ 1.0 (+ (square (mref matrix 0 i))
                             (square (mref matrix 1 i))
                             (square (mref matrix 2 i))))))
        (dotimes (j 3)
          (setf (mref inverse i j) (* scale (mref matrix j i))))))
    ;; translation: negation after dotting with upper rows
    (let ((x (mref matrix 0 3))
          (y (mref matrix 1 3))
          (z (mref matrix 2 3)))
      (dotimes (i 3)
        (setf (mref inverse i 3) (- (+ (* x (mref inverse i 0))
                                       (* y (mref inverse i 1))
                                       (* z (mref inverse i 2)))))))
    ;; affine bottom row (0 0 0 1)
    (dotimes (i 3)
      (setf (mref inverse 3 i) 0.0))
    (setf (mref inverse 3 3) 1.0)
    inverse))

(declaim (ftype (sfunction (matrix) matrix) transpose-matrix))
(defun transpose-matrix (matrix)
  "Transpose of MATRIX."
  (let ((transpose (zero-matrix)))
    (dotimes (i 4)
      (dotimes (j 4)
	(setf (mref transpose i j) (mref matrix j i))))
    transpose))