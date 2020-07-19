/*  SA-MP Actor Functions
//  *
//  *  (c) Copyright 2015, SA-MP Team
//  *
//  */

#if defined _actor_included
	#endinput
#endif
#define _actor_included
#pragma library actors

native IsActorStreamedIn(actorid, forplayerid);

native ApplyActorAnimation(actorid, const animlib[], const animname[], Float:fDelta, loop, lockx, locky, freeze, time);
native ClearActorAnimations(actorid);

native SetActorInvulnerable(actorid, invulnerable = true);
native IsActorInvulnerable(actorid);

native IsValidActor(actorid);