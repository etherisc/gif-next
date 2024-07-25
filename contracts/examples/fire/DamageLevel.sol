// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type DamageLevel is uint8;

// type bindings
using {
    DamageLevelLib.eq,
    DamageLevelLib.eqz,
    DamageLevelLib.toInt
} for DamageLevel global;

// solhint-disable-next-line func-name-mixedcase
function DAMAGE_SMALL() pure returns (DamageLevel) {
    return DamageLevel.wrap(1);
}

// solhint-disable-next-line func-name-mixedcase
function DAMAGE_MEDIUM() pure returns (DamageLevel) {
    return DamageLevel.wrap(2);
}

// solhint-disable-next-line func-name-mixedcase
function DAMAGE_LARGE() pure returns (DamageLevel) {
    return DamageLevel.wrap(3);
}

library DamageLevelLib {

    error ErrorDamageLeveLibInvalidDamageLevel(uint8 damageLevel);

    function zero() internal pure returns (DamageLevel) {
        return DamageLevel.wrap(0);
    }

    function toDamageLevel(uint8 damage) internal pure returns (DamageLevel) {
        if (damage == 1) {
            return DAMAGE_SMALL();
        } else if (damage == 2) {
            return DAMAGE_MEDIUM();
        } else if (damage == 3) {
            return DAMAGE_LARGE();
        } else {
            revert ErrorDamageLeveLibInvalidDamageLevel(damage);
        }
    }

    function toInt(DamageLevel damageLevel) internal pure returns (uint8) {
        return uint8(DamageLevel.unwrap(damageLevel));
    }

    function eq(DamageLevel a, DamageLevel b) internal pure returns (bool) {
        return DamageLevel.unwrap(a) == DamageLevel.unwrap(b);
    }

    function eqz(DamageLevel a) internal pure returns (bool) {
        return DamageLevel.unwrap(a) == 0;
    }
}