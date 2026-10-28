# Renaming a user/topic here reseeds every consumer at once, so an auth name can't drift.
{
  port = 2586;
  publisherUser = "publisher";
  readerUser = "reader";
  healthTopic = "nas-health";
  agentTopic = "agent-events";
}
