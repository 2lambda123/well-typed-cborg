{-# LANGUAGE DeriveDataTypeable #-}

-- |
-- Module      : Data.Binary.Serialise.CBOR.IO
-- Copyright   : (c) Duncan Coutts 2015
-- License     : BSD3-style (see LICENSE.txt)
--
-- Maintainer  : duncan@community.haskell.org
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--
-- High-level file-based API for serialising and deserialising values.
--
module Data.Binary.Serialise.CBOR.IO
  ( -- * @'FilePath'@ API
    writeFileSerialise
  , readFileDeserialise
    -- * @'System.IO.Handle'@ API
  , hPutSerialise
  ) where
import Data.Binary.Serialise.CBOR
