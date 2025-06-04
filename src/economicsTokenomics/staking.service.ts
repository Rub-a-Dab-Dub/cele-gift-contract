// economicsTokenomics/staking.service.ts
import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { StakingPosition } from "./entities/staking-position.entity";
import { RewardDistribution } from "./entities/reward-distribution.entity";
import {
  StakeTokensDto,
  UnstakeTokensDto,
  ClaimRewardsDto,
} from "./dto/staking.dto";
import { ethers } from "ethers";

@Injectable()
export class StakingService {
  constructor(
    @InjectRepository(StakingPosition)
    private stakingPositionRepository: Repository<StakingPosition>,
    @InjectRepository(RewardDistribution)
    private rewardDistributionRepository: Repository<RewardDistribution>
  ) {}

  async stakeTokens(stakeTokensDto: StakeTokensDto) {
    const { amount, poolId, lockPeriod = 0 } = stakeTokensDto;

    // Validate amount
    if (isNaN(parseFloat(amount)) || parseFloat(amount) <= 0) {
      throw new BadRequestException("Invalid stake amount");
    }

    const lockEndDate = new Date();
    lockEndDate.setDate(lockEndDate.getDate() + lockPeriod);

    const stakingPosition = this.stakingPositionRepository.create({
      userAddress: "user-address", // In real implementation, get from authenticated user
      stakedAmount: amount,
      rewardDebt: "0",
      pendingRewards: "0",
      stakingPoolId: poolId,
      lockPeriod,
      lockEndDate,
    });

    await this.stakingPositionRepository.save(stakingPosition);

    return {
      success: true,
      positionId: stakingPosition.id,
      stakedAmount: amount,
      lockEndDate,
    };
  }

  async unstakeTokens(unstakeTokensDto: UnstakeTokensDto) {
    const { amount, positionId } = unstakeTokensDto;

    const position = await this.stakingPositionRepository.findOne({
      where: { id: positionId },
    });
    if (!position) {
      throw new NotFoundException("Staking position not found");
    }

    // Check if lock period has ended
    if (new Date() < position.lockEndDate) {
      throw new BadRequestException("Tokens are still locked");
    }

    const stakedAmount = ethers.utils.parseEther(position.stakedAmount);
    const unstakeAmount = ethers.utils.parseEther(amount);

    if (unstakeAmount.gt(stakedAmount)) {
      throw new BadRequestException("Unstake amount exceeds staked amount");
    }

    // Calculate remaining amount
    const remainingAmount = stakedAmount.sub(unstakeAmount);

    if (remainingAmount.isZero()) {
      // Remove position if fully unstaked
      await this.stakingPositionRepository.delete(positionId);
    } else {
      // Update position with remaining amount
      await this.stakingPositionRepository.update(positionId, {
        stakedAmount: ethers.utils.formatEther(remainingAmount),
      });
    }

    return {
      success: true,
      unstakedAmount: amount,
      remainingStaked: ethers.utils.formatEther(remainingAmount),
    };
  }

  async claimRewards(claimRewardsDto: ClaimRewardsDto) {
    const { positionId } = claimRewardsDto;

    const position = await this.stakingPositionRepository.findOne({
      where: { id: positionId },
    });
    if (!position) {
      throw new NotFoundException("Staking position not found");
    }

    const pendingRewards = ethers.utils.parseEther(position.pendingRewards);

    if (pendingRewards.isZero()) {
      throw new BadRequestException("No rewards to claim");
    }

    // Create reward distribution record
    const rewardDistribution = this.rewardDistributionRepository.create({
      recipient: position.userAddress,
      amount: position.pendingRewards,
      rewardType: "staking",
      poolId: position.stakingPoolId,
      transactionHash: ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(`reward-${Date.now()}`)
      ),
      claimed: true,
    });

    await this.rewardDistributionRepository.save(rewardDistribution);

    // Reset pending rewards
    await this.stakingPositionRepository.update(positionId, {
      pendingRewards: "0",
      rewardDebt: ethers.utils.formatEther(pendingRewards),
    });

    return {
      success: true,
      claimedAmount: position.pendingRewards,
      transactionHash: rewardDistribution.transactionHash,
    };
  }

  async getUserStakingPositions(userAddress: string) {
    const positions = await this.stakingPositionRepository.find({
      where: { userAddress, isActive: true },
      order: { createdAt: "DESC" },
    });

    return { positions };
  }

  async getStakingPools() {
    // In a real implementation, this would come from a pools configuration
    return {
      pools: [
        {
          id: "pool-1",
          name: "Standard Staking Pool",
          apy: "12.5",
          lockPeriod: 0,
          minStake: "100",
        },
        {
          id: "pool-2",
          name: "30-Day Lock Pool",
          apy: "18.0",
          lockPeriod: 30,
          minStake: "500",
        },
        {
          id: "pool-3",
          name: "90-Day Lock Pool",
          apy: "25.0",
          lockPeriod: 90,
          minStake: "1000",
        },
      ],
    };
  }

  async getPendingRewards(userAddress: string) {
    const positions = await this.stakingPositionRepository.find({
      where: { userAddress, isActive: true },
    });

    let totalPendingRewards = ethers.BigNumber.from(0);
    const positionRewards = [];

    for (const position of positions) {
      const pendingRewards = ethers.utils.parseEther(position.pendingRewards);
      totalPendingRewards = totalPendingRewards.add(pendingRewards);

      positionRewards.push({
        positionId: position.id,
        pendingRewards: position.pendingRewards,
        stakedAmount: position.stakedAmount,
      });
    }

    return {
      totalPendingRewards: ethers.utils.formatEther(totalPendingRewards),
      positions: positionRewards,
    };
  }

  async getStakingStats() {
    const totalPositions = await this.stakingPositionRepository.count({
      where: { isActive: true },
    });

    const result = await this.stakingPositionRepository
      .createQueryBuilder("position")
      .select("SUM(CAST(position.stakedAmount AS DECIMAL))", "totalStaked")
      .where("position.isActive = :isActive", { isActive: true })
      .getRawOne();

    const totalStaked = result?.totalStaked || "0";

    return {
      totalStaked,
      totalStakers: totalPositions,
      averageStakePerUser:
        totalPositions > 0
          ? (parseFloat(totalStaked) / totalPositions).toString()
          : "0",
    };
  }
}
