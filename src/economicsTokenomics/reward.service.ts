// economicsTokenomics/reward.service.ts
import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { RewardDistribution } from "./entities/reward-distribution.entity";
import { StakingPosition } from "./entities/staking-position.entity";
import { ethers } from "ethers";

@Injectable()
export class RewardService {
  constructor(
    @InjectRepository(RewardDistribution)
    private rewardDistributionRepository: Repository<RewardDistribution>,
    @InjectRepository(StakingPosition)
    private stakingPositionRepository: Repository<StakingPosition>
  ) {}

  async getRewardHistory(userAddress: string, page: number, limit: number) {
    const [rewards, total] =
      await this.rewardDistributionRepository.findAndCount({
        where: { recipient: userAddress },
        order: { createdAt: "DESC" },
        skip: (page - 1) * limit,
        take: limit,
      });

    return {
      rewards,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getRewardStats() {
    const totalRewards = await this.rewardDistributionRepository
      .createQueryBuilder("reward")
      .select("SUM(CAST(reward.amount AS DECIMAL))", "total")
      .getRawOne();

    const rewardsByType = await this.rewardDistributionRepository
      .createQueryBuilder("reward")
      .select("reward.rewardType", "type")
      .addSelect("SUM(CAST(reward.amount AS DECIMAL))", "total")
      .groupBy("reward.rewardType")
      .getRawMany();

    return {
      totalRewardsDistributed: totalRewards?.total || "0",
      rewardsByType,
    };
  }

  async calculateRewards() {
    const stakingPositions = await this.stakingPositionRepository.find({
      where: { isActive: true },
    });

    const rewardRate = ethers.utils.parseEther("0.000034722"); // ~12.5% APY per second

    for (const position of stakingPositions) {
      const stakedAmount = ethers.utils.parseEther(position.stakedAmount);
      const timeStaked = Math.floor(
        (Date.now() - position.createdAt.getTime()) / 1000
      );

      let multiplier = 100; // Base 1x
      if (position.lockPeriod >= 90) {
        multiplier = 200; // 2x for 90+ days
      } else if (position.lockPeriod >= 30) {
        multiplier = 150; // 1.5x for 30+ days
      }

      const baseReward = stakedAmount.mul(rewardRate).mul(timeStaked);
      const finalReward = baseReward.mul(multiplier).div(100);

      await this.stakingPositionRepository.update(position.id, {
        pendingRewards: ethers.utils.formatEther(finalReward),
      });
    }

    return {
      success: true,
      updatedPositions: stakingPositions.length,
      timestamp: new Date(),
    };
  }

  async getPoolAPY(poolId: string) {
    // Calculate APY based on pool configuration
    const poolAPYs = {
      "pool-1": "12.5",
      "pool-2": "18.0",
      "pool-3": "25.0",
    };

    return {
      poolId,
      apy: poolAPYs[poolId] || "0",
      calculatedAt: new Date(),
    };
  }
}