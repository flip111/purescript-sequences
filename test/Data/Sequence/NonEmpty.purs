module Tests.Data.Sequence.NonEmpty (nonEmptySequenceTests) where

import Prelude

import Data.Array as A
import Data.Foldable (all, foldl, foldr, sum)
import Data.Maybe (Maybe(..))
import Data.Semigroup.Foldable (fold1, foldMap1)
import Data.Sequence as S
import Data.Sequence.NonEmpty as NonEmpty
import Data.Tuple (Tuple(..), fst, snd)
import Data.Unfoldable (replicate1, unfoldr1)
import Effect (Effect)
import Effect.Console (log)
import Test.Assert (assert)
import Test.QuickCheck ((<?>), (===), quickCheck)
import Test.QuickCheck.Laws (A)
import Test.QuickCheck.Laws.Control.Alt (checkAlt)
import Test.QuickCheck.Laws.Control.Applicative (checkApplicative)
import Test.QuickCheck.Laws.Control.Apply (checkApply)
import Test.QuickCheck.Laws.Control.Bind (checkBind)
import Test.QuickCheck.Laws.Control.Monad (checkMonad)
import Test.QuickCheck.Laws.Data.Eq (checkEq)
import Test.QuickCheck.Laws.Data.Functor (checkFunctor)
import Test.QuickCheck.Laws.Data.Ord (checkOrd)
import Test.QuickCheck.Laws.Data.Semigroup (checkSemigroup)
import Tests.Utils (ArbNESeq(..), err, abs, integerBetween, foldableSize)
import Type.Proxy (Proxy(..))

arr :: forall a. NonEmpty.Seq a -> Array a
arr = NonEmpty.toUnfoldable

prx :: Proxy (ArbNESeq A)
prx = Proxy

prx2 :: Proxy ArbNESeq
prx2 = Proxy

nonEmptySequenceTests :: Effect Unit
nonEmptySequenceTests = do
  log ""
  log "Data.Sequence.NonEmpty"
  log "======================"
  log ""

  checkEq prx
  checkOrd prx
  checkFunctor prx2
  checkApply prx2
  checkApplicative prx2
  checkBind prx2
  checkMonad prx2
  checkSemigroup prx
  checkAlt prx2

  log "Test toUnfoldable homomorphism"
  quickCheck $ \(ArbNESeq x) (ArbNESeq y) ->
    arr (x <> y) == arr x <> (arr y :: Array Int)
    <?> ("x: " <> show x <> ", y: " <> show y)

  log "Test foldable instance"
  quickCheck $ \f z (ArbNESeq xs) ->
    let types = Tuple (f :: Int -> Int -> Int) (z :: Int)
    in  foldr f z xs == foldr f z (arr xs :: Array Int)

  quickCheck $ \f z (ArbNESeq xs) ->
    let types = Tuple (f :: Int -> Int -> Int) (z :: Int)
    in  foldl f z xs == foldl f z (arr xs :: Array Int)

  quickCheck $ \(ArbNESeq xs) ->
    A.length (arr xs) == foldableSize (xs :: NonEmpty.Seq Int)

  quickCheck $ \(ArbNESeq xs) ->
    NonEmpty.length xs + 1 == NonEmpty.length (NonEmpty.cons 0 xs)
  quickCheck $ \(ArbNESeq xs) ->
    NonEmpty.length xs - 1 == S.length (NonEmpty.drop 1 (xs :: NonEmpty.Seq Int))

  log "Test splitAt/head/last"
  quickCheck $ \idx (ArbNESeq seq) ->
    let idx' :: Int
        idx' = integerBetween 0 (NonEmpty.length seq) idx

        split :: Tuple (S.Seq Int) (S.Seq Int)
        split = NonEmpty.splitAt idx' seq

    in  S.last (fst split) == NonEmpty.index (idx' - 1) seq
          && S.head (snd split) == NonEmpty.index idx' seq
          <?> ("seq: " <> show seq <> ", idx':" <> show idx')

  log "Test that adjust is safe"
  quickCheck $ \(ArbNESeq seq) ->
    let f n = NonEmpty.adjust identity n (seq :: NonEmpty.Seq Int)
    in f (-1) == f (NonEmpty.length seq)

  log "Test that index is safe"
  quickCheck $ \(ArbNESeq seq) ->
    let f n = NonEmpty.index n (seq :: NonEmpty.Seq Int)
    in f (-1) == Nothing && f (NonEmpty.length seq) == Nothing

  log "Test inBounds"
  quickCheck $ \(ArbNESeq seq) ->
    let lowerBound = 0
        upperBound = NonEmpty.length seq - 1
        types = (seq :: NonEmpty.Seq Int)
    in NonEmpty.inBounds lowerBound seq && NonEmpty.inBounds upperBound seq
        && not (NonEmpty.inBounds (lowerBound - 1) seq)
        && not (NonEmpty.inBounds (upperBound + 1) seq)

  log "Test adjust"
  quickCheck $ \(ArbNESeq seq) idx ->
    let seq' = const 0 <$> (seq :: NonEmpty.Seq Unit)
        idx' = integerBetween 0 (NonEmpty.length seq') idx
        result = sum (NonEmpty.adjust (_+1) idx' seq')
    in  result == 1 <?> "seq': " <> show seq' <> ", result: " <> show result

  log "Test take"
  quickCheck $ \(ArbNESeq seq) n ->
    let result = S.length (NonEmpty.take n (seq :: NonEmpty.Seq Int))
    in 0 <= result && result <= abs n <?> err [ "n = " <> show n
                                              , "seq = " <> show seq
                                              , "result = " <> show result
                                              ]

  log "Test drop"
  quickCheck $ \(ArbNESeq seq) n ->
    let dropped = NonEmpty.length (seq :: NonEmpty.Seq Int) - S.length (NonEmpty.drop n seq)
    in 0 <= dropped && dropped <= abs n <?> err [ "n = " <> show n
                                                , "seq = " <> show seq
                                                , "dropped = " <> show dropped
                                                ]

  log "Test filter"
  quickCheck $ \(ArbNESeq seq) -> S.null (NonEmpty.filter (const false) (seq :: NonEmpty.Seq Int))
  quickCheck $ \(ArbNESeq seq) -> NonEmpty.filter (const true) seq === (NonEmpty.toPlain seq :: S.Seq Int)
  quickCheck $ \(ArbNESeq seq) f -> all f (NonEmpty.filter f (seq :: NonEmpty.Seq Int))

  log "Test length"
  quickCheck $ \(ArbNESeq seq) -> NonEmpty.length (seq :: NonEmpty.Seq Int) >= 1 <?> show seq

  log "Test cons/uncons"
  quickCheck $ \(ArbNESeq seq) x ->
    NonEmpty.uncons (NonEmpty.cons x seq) === Tuple (x :: Int) (NonEmpty.toPlain seq)
  quickCheck $ \(ArbNESeq seq) x ->
    NonEmpty.unsnoc (NonEmpty.snoc seq x) === Tuple (NonEmpty.toPlain seq) (x :: Int)

  log "Test init"
  quickCheck $ \(ArbNESeq seq) ->
    NonEmpty.init seq === NonEmpty.take (NonEmpty.length seq - 1) (seq :: NonEmpty.Seq Int)

  log "Test tail"
  quickCheck $ \(ArbNESeq seq) ->
    NonEmpty.tail seq === NonEmpty.drop 1 (seq :: NonEmpty.Seq Int)

  log "Test head"
  quickCheck $ \(ArbNESeq seq) x ->
    NonEmpty.head (NonEmpty.cons x seq) === (x :: Int)

  log "Test last"
  quickCheck $ \(ArbNESeq seq) x ->
    NonEmpty.last (NonEmpty.snoc seq x) === (x :: Int)

  log "unfoldr1 should be stack-safe"
  assert $ 100000 == NonEmpty.length (replicate1 100000 1)

  let oneToFive = unfoldr1 step1 1 :: NonEmpty.Seq Int

  log "unfoldr1 should maintain order"
  assert $ NonEmpty.toUnfoldable oneToFive == [1, 2, 3, 4, 5]

  log "fold1 should maintain order"
  assert $ fold1 (map pure oneToFive) == [1, 2, 3, 4, 5]

  log "foldMap1 should maintain order"
  assert $ foldMap1 pure oneToFive == [1, 2, 3, 4, 5]

step1 :: Int -> Tuple Int (Maybe Int)
step1 5 = Tuple 5 Nothing
step1 n = Tuple n (Just (n + 1))
