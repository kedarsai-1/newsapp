const { prisma } = require('../config/prisma');
const cacheService = require('../utils/cacheService');
const { applyLanguageFilter } = require('../utils/feedLanguageFilter');
const cricApi = require('../services/cricApiService');
const { serializeNewsPost } = require('../utils/serializers');
const { newsPostInclude } = require('../utils/prismaNewsPost');

const TTL_NEWS_MS = 10 * 60 * 1000;

function newsThumb(post) {
  const m = post.media?.[0];
  if (!m?.url) return null;
  if (m.type === 'image') return m.url;
  if (m.type === 'video' && post.youtube?.thumbnailUrl) return post.youtube.thumbnailUrl;
  return m.url;
}

function normalizeNewsPost(post) {
  const o = post.toObject ? post.toObject() : post;
  return {
    id: String(o._id),
    title: o.title,
    thumbnail: newsThumb(o),
    time: o.sourcePublishedAt || o.createdAt,
    source: o.sourceName || o.category?.name || 'Sports',
    hasVideo: Boolean(
      o.media?.some((x) => x.type === 'video') || o.youtube?.videoId,
    ),
    youtubeVideoId: o.youtube?.videoId || null,
    youtubeUrl: o.youtube?.videoId
      ? `https://www.youtube.com/watch?v=${o.youtube.videoId}`
      : null,
  };
}

async function resolveSportsCategoryId() {
  const cacheKey = 'sports:categoryId';
  const hit = await cacheService.get(cacheKey);
  if (hit) return hit;
  const cat = await prisma.category.findFirst({
    where: { slug: 'sports', isActive: true },
    select: { id: true },
  });
  const id = cat?.id ? String(cat.id) : null;
  await cacheService.set(cacheKey, id, TTL_NEWS_MS);
  return id;
}

/** GET /api/sports/live — live + upcoming (minimal payload). */
const getLive = async (req, res) => {
  try {
    if (!cricApi.hasKey()) {
      return res.json({
        success: true,
        live: [],
        upcoming: [],
        message: 'Configure CRICAPI_KEY on the server for live scores.',
        cached: false,
      });
    }
    const data = await cricApi.fetchCurrentMatches();
    const empty =
      !data.live?.length && !data.upcoming?.length && !(data.ipl || []).length;
    const noIplLive =
      !(data.live || []).some((m) => /ipl|indian premier league/i.test(`${m.tournament || ''}`))
      && !(data.upcoming || []).some((m) => /ipl|indian premier league/i.test(`${m.tournament || ''}`));
    let message = empty
      ? 'No live or upcoming matches right now. Pull to refresh in a few minutes.'
      : data.warning || null;
    if (!empty && noIplLive && !(data.ipl || []).length) {
      message =
        'No live IPL match right now. The current season may be over — check back when IPL fixtures resume.';
    }

    return res.json({
      success: true,
      live: data.live,
      upcoming: data.upcoming,
      ipl: data.ipl || [],
      iplSectionTitle: data.iplSectionTitle || 'IPL',
      iplSeasonYear: data.iplSeasonYear || null,
      cached: true,
      stale: Boolean(data.stale),
      warning: data.warning || null,
      message,
      fetchedAt: data.fetchedAt,
    });
  } catch (e) {
    console.error('[sports] live', e.message);
    const rateLimited = /blocked|limit|quota|exceeded/i.test(e.message);
    return res.status(502).json({
      success: false,
      message: rateLimited
        ? 'Cricket API daily limit reached. Scores will return after the quota resets (usually within an hour).'
        : 'Could not load live cricket scores.',
    });
  }
};

/** GET /api/sports/match/:id — match detail (minimal). */
const getMatch = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: 'Match id required.' });
    }
    if (!cricApi.hasKey()) {
      return res.status(503).json({
        success: false,
        message: 'CricAPI not configured.',
      });
    }
    const match = await cricApi.fetchMatchById(id);
    if (!match) {
      return res.status(404).json({ success: false, message: 'Match not found.' });
    }

    // Look up poll in DB
    let poll = await prisma.matchPoll.findUnique({
      where: { matchId: id }
    });

    // If poll doesn't exist, and we have enough info, initialize it on-the-fly
    if (!poll && match.teams && Array.isArray(match.teams) && match.teams.length >= 2) {
      try {
        poll = await prisma.matchPoll.create({
          data: {
            matchId: id,
            optionATitle: match.teams[0].name || 'Team A',
            optionBTitle: match.teams[1].name || 'Team B',
          }
        });
      } catch (createErr) {
        // Handle potential database write race conditions
        poll = await prisma.matchPoll.findUnique({ where: { matchId: id } });
      }
    }

    // If the poll is not resolved yet, and the match is ended, resolve the prediction points!
    if (
      poll &&
      !poll.isResolved &&
      (match.status === 'ended' || match.status === 'finished' || match.matchWinner)
    ) {
      try {
        let winningOption = null;
        if (match.matchWinner) {
          const winnerLower = match.matchWinner.toLowerCase().trim();
          const optALower = poll.optionATitle.toLowerCase().trim();
          const optBLower = poll.optionBTitle.toLowerCase().trim();

          if (winnerLower.includes(optALower) || optALower.includes(winnerLower)) {
            winningOption = 'A';
          } else if (winnerLower.includes(optBLower) || optBLower.includes(winnerLower)) {
            winningOption = 'B';
          }
        }

        // If it's a draw, tie or no result (or matchWinner could not be mapped to option A or B)
        if (!winningOption) {
          await prisma.$transaction(async (tx) => {
            await tx.matchPollVote.updateMany({
              where: { pollId: poll.id, isProcessed: false },
              data: {
                isProcessed: true,
                isCorrect: null // null indicates a draw
              }
            });

            poll = await tx.matchPoll.update({
              where: { id: poll.id },
              data: {
                isResolved: true,
                winnerOption: null
              }
            });
          });
        } else {
          await prisma.$transaction(async (tx) => {
            const unprocessedVotes = await tx.matchPollVote.findMany({
              where: { pollId: poll.id, isProcessed: false }
            });

            for (const vote of unprocessedVotes) {
              const isCorrect = (vote.option === winningOption);
              if (isCorrect) {
                const user = await tx.user.findUnique({
                  where: { id: vote.userId },
                  select: { points: true, predictionStreak: true, maxPredictionStreak: true }
                });
                if (user) {
                  const newStreak = user.predictionStreak + 1;
                  const newMaxStreak = Math.max(newStreak, user.maxPredictionStreak);
                  await tx.user.update({
                    where: { id: vote.userId },
                    data: {
                      points: { increment: 100 },
                      predictionStreak: newStreak,
                      maxPredictionStreak: newMaxStreak
                    }
                  });
                }
              } else {
                await tx.user.update({
                  where: { id: vote.userId },
                  data: {
                    predictionStreak: 0
                  }
                });
              }

              await tx.matchPollVote.update({
                where: { id: vote.id },
                data: {
                  isProcessed: true,
                  isCorrect: isCorrect
                }
              });
            }

            poll = await tx.matchPoll.update({
              where: { id: poll.id },
              data: {
                isResolved: true,
                winnerOption: winningOption
              }
            });
          });
        }
      } catch (resolutionErr) {
        console.error('[sports] poll resolution failed:', resolutionErr.message);
      }
    }

    let userVote = null;
    let userVoteCorrect = null;
    if (req.user?._id && poll) {
      const voteEntry = await prisma.matchPollVote.findUnique({
        where: {
          pollId_userId: {
            pollId: poll.id,
            userId: req.user._id
          }
        }
      });
      userVote = voteEntry?.option || null;
      userVoteCorrect = voteEntry ? voteEntry.isCorrect : null;
    }

    const pollData = poll ? {
      id: poll.id,
      optionATitle: poll.optionATitle,
      optionBTitle: poll.optionBTitle,
      votesA: poll.votesA,
      votesB: poll.votesB,
      totalVotes: poll.votesA + poll.votesB,
      userVote,
      userVoteCorrect,
      isResolved: poll.isResolved,
      winnerOption: poll.winnerOption,
    } : null;

    return res.json({
      success: true,
      match,
      poll: pollData
    });
  } catch (e) {
    console.error('[sports] match', e.message);
    if (e.code === 'CRICAPI_NOT_FOUND' || /match not found/i.test(e.message)) {
      return res.status(404).json({ success: false, message: 'Match not found.' });
    }
    return res.status(502).json({
      success: false,
      message: 'Could not load match details.',
    });
  }
};

/** POST /api/sports/match/:id/poll/vote — cast vote */
const voteMatchPoll = async (req, res) => {
  try {
    const { id } = req.params;
    const { option } = req.body; // "A" or "B"

    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Login required to vote.' });
    }
    if (option !== 'A' && option !== 'B') {
      return res.status(400).json({ success: false, message: 'Invalid option. Must be A or B.' });
    }

    let poll = await prisma.matchPoll.findUnique({
      where: { matchId: id }
    });

    if (!poll) {
      const match = await cricApi.fetchMatchById(id);
      if (match && match.teams && Array.isArray(match.teams) && match.teams.length >= 2) {
        try {
          poll = await prisma.matchPoll.create({
            data: {
              matchId: id,
              optionATitle: match.teams[0].name || 'Team A',
              optionBTitle: match.teams[1].name || 'Team B',
            }
          });
        } catch (createErr) {
          poll = await prisma.matchPoll.findUnique({ where: { matchId: id } });
        }
      }
    }

    if (!poll) {
      return res.status(404).json({ success: false, message: 'Poll not found for this match.' });
    }

    if (poll.isResolved) {
      return res.status(400).json({
        success: false,
        message: 'Poll is closed. Voting has ended.',
      });
    }

    let matchStatus = null;
    try {
      const match = await cricApi.fetchMatchById(id);
      matchStatus = match?.status || null;
      if (
        matchStatus === 'finished'
        || matchStatus === 'ended'
        || match?.matchWinner
      ) {
        return res.status(400).json({
          success: false,
          message: 'Match has ended. Voting is closed.',
        });
      }
    } catch (matchErr) {
      if (matchErr.code === 'CRICAPI_NOT_FOUND') {
        return res.status(404).json({ success: false, message: 'Match not found.' });
      }
      // Allow vote if live scores API is temporarily down but poll is still open.
    }

    const userId = req.user._id;
    const existingVote = await prisma.matchPollVote.findUnique({
      where: {
        pollId_userId: {
          pollId: poll.id,
          userId
        }
      }
    });

    if (existingVote) {
      return res.status(400).json({ success: false, message: 'You have already voted in this poll.' });
    }

    // Cast vote in database transaction
    const [newVote, updatedPoll] = await prisma.$transaction([
      prisma.matchPollVote.create({
        data: {
          pollId: poll.id,
          userId,
          option
        }
      }),
      prisma.matchPoll.update({
        where: { id: poll.id },
        data: {
          votesA: option === 'A' ? { increment: 1 } : undefined,
          votesB: option === 'B' ? { increment: 1 } : undefined,
        }
      })
    ]);

    return res.json({
      success: true,
      poll: {
        id: updatedPoll.id,
        optionATitle: updatedPoll.optionATitle,
        optionBTitle: updatedPoll.optionBTitle,
        votesA: updatedPoll.votesA,
        votesB: updatedPoll.votesB,
        totalVotes: updatedPoll.votesA + updatedPoll.votesB,
        userVote: option
      }
    });
  } catch (e) {
    console.error('[sports] vote failed:', e.message);
    return res.status(500).json({ success: false, message: 'Failed to cast vote.' });
  }
};

function parseFeedLanguage(req) {
  const raw = req.query.language;
  if (!raw || String(raw).toLowerCase() === 'all') return null;
  return String(raw).toLowerCase();
}

/** GET /api/sports/news — cricket/sports posts from existing news DB. */
const getNews = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(30, Math.max(5, parseInt(req.query.limit, 10) || 15));
    const langParam = parseFeedLanguage(req);
    const cacheKey = `sports:news:${langParam || 'all'}:${page}:${limit}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({ ...cached, cached: true });
    }

    const categoryId = await resolveSportsCategoryId();
    let query = { status: 'approved' };
    if (categoryId) {
      query.categoryId = categoryId;
    } else {
      query.OR = [
        { tags: { hasSome: ['cricket', 'ipl', 'sports', 'wpl', 't20', 'odi'] } },
        { title: { contains: 'cricket', mode: 'insensitive' } },
        { title: { contains: 'ipl', mode: 'insensitive' } },
      ];
    }
    query = applyLanguageFilter(query, langParam);

    const skip = (page - 1) * limit;
    const [posts, total] = await Promise.all([
      prisma.newsPost.findMany({
        where: query,
        include: newsPostInclude,
        orderBy: [{ sourcePublishedAt: 'desc' }, { createdAt: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.newsPost.count({ where: query }),
    ]);

    const items = posts.map((post) => normalizeNewsPost(serializeNewsPost(post)));
    const pages = Math.ceil(total / limit) || 1;
    const payload = {
      success: true,
      news: items,
      page,
      pages,
      total,
      cached: false,
    };
    await cacheService.set(cacheKey, payload, TTL_NEWS_MS);
    return res.json(payload);
  } catch (e) {
    console.error('[sports] news', e.message);
    return res.status(500).json({
      success: false,
      message: 'Could not load sports news.',
    });
  }
};

const getLeaderboard = async (req, res) => {
  try {
    const topUsersCacheKey = 'sports:leaderboard:top10';
    let topUsers = await cacheService.get(topUsersCacheKey);
    
    if (!topUsers) {
      topUsers = await prisma.user.findMany({
        where: {
          isActive: true,
          points: { gt: 0 }
        },
        select: {
          id: true,
          name: true,
          avatar: true,
          points: true,
          predictionStreak: true,
          maxPredictionStreak: true,
        },
        orderBy: [
          { points: 'desc' },
          { maxPredictionStreak: 'desc' },
          { name: 'asc' }
        ],
        take: 10
      });
      await cacheService.set(topUsersCacheKey, topUsers, 30000); // Cache for 30 seconds
    }

    let currentUserStats = null;
    if (req.user?._id) {
      const userCacheKey = `sports:leaderboard:user:${req.user._id}`;
      currentUserStats = await cacheService.get(userCacheKey);
      
      if (!currentUserStats) {
        const user = await prisma.user.findUnique({
          where: { id: req.user._id },
          select: {
            id: true,
            name: true,
            avatar: true,
            points: true,
            predictionStreak: true,
            maxPredictionStreak: true
          }
        });
        if (user) {
          const higherCount = await prisma.user.count({
            where: {
              isActive: true,
              points: { gt: user.points }
            }
          });
          currentUserStats = {
            ...user,
            rank: higherCount + 1
          };
          await cacheService.set(userCacheKey, currentUserStats, 30000); // Cache for 30 seconds
        }
      }
    }

    return res.json({
      success: true,
      leaderboard: topUsers.map((u, i) => ({ ...u, rank: i + 1 })),
      currentUser: currentUserStats
    });
  } catch (error) {
    console.error('[sports] leaderboard failed:', error.message);
    return res.status(500).json({ success: false, message: 'Could not load leaderboard.' });
  }
};

module.exports = { getLive, getMatch, getNews, voteMatchPoll, getLeaderboard };
