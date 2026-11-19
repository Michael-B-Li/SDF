## Claim
Let $f_e(p)$ be the value of an SDF expression $e$ at point $p$, and let $A(e,R)$ be the interval computed for $e$ over an axis-aligned region $R$. For every valid expression $e$ and every region $R$,

$$
p\in R \quad\Longrightarrow\quad f_e(p)\in A(e,R).
$$

## Proof
By structural induction on $e$. Using the minimum and maximum preserve bounds because they increase in each argument.
For the Euclidean norm, we first bound the absolute value of each coordinate. The norm is increasing in each nonnegative coordinate, so applying it to the lower and upper endpoints give valid bounds.

Base case: Sphere
Let $e=\operatorname{Sphere}(r)$. If $p\in R$, each coordinate of $p$ lies in its corresponding interval. The interval norm therefore contains $\|p\|_2$. Subtracting $r$ from both endpoints gives an interval containing $\|p\|_2-r=f_e(p)$.

Base case: Box
Let $e=\operatorname{Box}(h)$, where $h$ gives the half-dimensions. For each coordinate $i$, interval absolute value and subtraction give an ineterval containing $q_i=|p_i|-h_i$. Applying interval maximum with zero and then the interval norm it bounds the outside term $\|\max(q,0)\|_2$. Applying interval maximum across the three coordinates and then minimum with zero bounds the inside term $\min(\max(q_x,q_y,q_z),0)$. Therefore adding the two intervals therefore contains their sum, $f_e(p)$.

Inductive case: Translation
Let $e=\operatorname{Translate}(t,a)$. f $p\in R$, then $p-t\in R-t$. The induction hypothesis for $a$ holds for every region, so we can apply it to $R-t$. It gives $f_a(p-t)\in A(a,R-t)$. These are the translated field value $f_e(p)$ and the interval $A(e,R)$.

Inductive cases: Union Intersection Difference
Assume the claim holds for both children $a$ and $b$. For any $p\in R$, we write $A(a,R)=[l_a,u_a]$ and $A(b,R)=[l_b,u_b]$. The induction hypothesis puts $f_a(p)$ and $f_b(p)$ in their respective intervals.
- Union. The value $\min(f_a(p),f_b(p))$ lies between $\min(l_a,l_b)$ and $\min(u_a,u_b)$.
- Intersection. The value $\max(f_a(p),f_b(p))$ lies between $\max(l_a,l_b)$ and $\max(u_a,u_b)$.
- Difference. We can negate the second interval which gives $-f_b(p)\in[-u_b,-l_b]$. Therefore $\max(f_a(p),-f_b(p))$ lies between $\max(l_a,-u_b)$ and $\max(u_a,-l_b)$.

In each case, those endpoints are exactly the ones computed by interval evaluation. This covers all six constructors, so the claim holds for every valid expression. $\square$
