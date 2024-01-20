#if defined _tf2_stun_included_
  #endinput
#endif
#define _tf2_stun_included_

/**
 * When CTFPlayerShared::OnAddStunned Called.
 * 
 * @param client        Client index.
 * @param duration      Stun duration.
 * @param slowdown      Slowdown rate. from 0(no slowdown) to 255(can't move).
 * @param stunflags     Stun flags. See tf2.inc.
 * @param stunner       Stunner index. -1 when no stunner.
 * 
 * @noreturn
 */
forward void TF2_OnAddStunned(int client, float duration, int slowdown, int stunflags, int stunner);

/**
 * When CTFPlayerShared::OnRemoveStunned Called.
 * 
 * @param client        Client index.
 * @param duration      Stun duration.
 * @param slowdown      Slowdown rate. from 0(no slowdown) to 255(can't move).
 * @param stunflags     Stun flags. See tf2.inc.
 * @param stunner       Stunner index. -1 when no stunner.
 * 
 * @noreturn
 */
forward void TF2_OnRemoveStunned(int client, float duration, int slowdown, int stunflags, int stunner);

public SharedPlugin __pl_tf2_stun = {
	name = "tf2_stun",
	file = "tf2_stun.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};