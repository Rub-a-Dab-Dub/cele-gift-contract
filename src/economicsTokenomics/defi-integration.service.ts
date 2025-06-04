// economicsTokenomics/defi-integration.service.ts
import { Injectable, BadRequestException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { LiquidityPosition } from "./entities/liquidity-position.entity";
import { RewardDistribution } from "./entities/reward-distribution.entity";
import { ethers } from "ethers";

@Injectable()
export class DeFiIntegrationService {
  constructor(
    @InjectRepository(LiquidityPosition)
    private liquidityPositionRepository: Repository<LiquidityPosition>,
    @InjectRepository(RewardDistribution)
    private rewardDistributionRepository: Repository<RewardDistribution>
  ) {}

  async addLiquidity(
    userAddress: string,
    poolAddress: string,
    lpTokenAmount: string
  ) {
    if (isNaN(parseFloat(lpTokenAmount)) || parseFloat(lpTokenAmount) <= 0) {
      throw new BadRequestException("Invalid LP token amount");
    }

    const liquidityPosition = this.liquidityPositionRepository.create({
      userAddress,
      poolAddress,
      lpTokenAmount,
      rewardDebt: "0",
      pendingRewards: "0",
    });

    await this.liquidityPositionRepository.save(liquidityPosition);

    return {
      success: true,
      positionId: liquidityPosition.id,
      lpTokenAmount,
    };
  }

  async removeLiquidity(positionId: string, lpTokenAmount: string) {
    const position = await this.liquidityPositionRepository.findOne({
      where: { id: positionId },
    });

    if (!position) {
      throw new BadRequestException("Liquidity position not found");
    }

    const currentLP = ethers.utils.parseEther(position.lpTokenAmount);
    const removeLP = ethers.utils.parseEther(lpTokenAmount);

    if (removeLP.gt(currentLP)) {
      throw new BadRequestException("Insufficient LP tokens");
    }

    const remainingLP = currentLP.sub(removeLP);

    if (remainingLP.isZero()) {
      await this.liquidityPositionRepository.delete(positionId);
    } else {
      await this.liquidityPositionRepository.update(positionId, {
        lpTokenAmount: ethers.utils.formatEther(remainingLP),
      });
    }

    return {
      success: true,
      removedAmount: lpTokenAmount,
      remainingAmount: ethers.utils.formatEther(remainingLP),
    };
  }

  async calculateLiquidityRewards() {
    const positions = await this.liquidityPositionRepository.find({
      where: { isActive: true },
    });

    const liquidityRewardRate = ethers.utils.parseEther("0.000023148"); // ~8.4% APY

    for (const position of positions) {
      const lpAmount = ethers.utils.parseEther(position.lpTokenAmount);
      const timeProvided = Math.floor(
        (Date.now() - position.createdAt.getTime()) / 1000
      );
      const rewards = lpAmount.mul(liquidityRewardRate).mul(timeProvided);

      await this.liquidityPositionRepository.update(position.id, {
        pendingRewards: ethers.utils.formatEther(rewards),
      });
    }

    return {
      success: true,
      updatedPositions: positions.length,
      timestamp: new Date(),
    };
  }

  async claimLiquidityRewards(positionId: string) {
    const position = await this.liquidityPositionRepository.findOne({
      where: { id: positionId },
    });

    if (!position) {
      throw new BadRequestException("Liquidity position not found");
    }

    const pendingRewards = ethers.utils.parseEther(position.pendingRewards);

    if (pendingRewards.isZero()) {
      throw new BadRequestException("No rewards to claim");
    }

    const rewardDistribution = this.rewardDistributionRepository.create({
      recipient: position.userAddress,
      amount: position.pendingRewards,
      rewardType: "liquidity",
      poolId: position.poolAddress,
      transactionHash: ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(`liq-reward-${Date.now()}`)
      ),
      claimed: true,
    });

    await this.rewardDistributionRepository.save(rewardDistribution);

    await this.liquidityPositionRepository.update(positionId, {
      pendingRewards: "0",
      rewardDebt: ethers.utils.formatEther(pendingRewards),
    });

    return {
      success: true,
      claimedAmount: position.pendingRewards,
      transactionHash: rewardDistribution.transactionHash,
    };
  }

  async getLiquidityPositions(userAddress: string) {
    const positions = await this.liquidityPositionRepository.find({
      where: { userAddress, isActive: true },
      order: { createdAt: "DESC" },
    });

    return { positions };
  }

  async getTotalLiquidityStats() {
    const totalPositions = await this.liquidityPositionRepository.count({
      where: { isActive: true },
    });

    const result = await this.liquidityPositionRepository
      .createQueryBuilder("position")
      .select("SUM(CAST(position.lpTokenAmount AS DECIMAL))", "totalLP")
      .where("position.isActive = :isActive", { isActive: true })
      .getRawOne();

    const totalLP = result?.totalLP || "0";

    return {
      totalLiquidityProviders: totalPositions,
      totalLPTokens: totalLP,
    };
  }
}
