// economicsTokenomics/reward.controller.ts
import { Controller, Get, Post, Body, Param, Query } from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from "@nestjs/swagger";
import { RewardService } from "./reward.service";

@ApiTags("Rewards")
@Controller("rewards")
export class RewardController {
  constructor(private readonly rewardService: RewardService) {}

  @Get("history/:userAddress")
  @ApiOperation({ summary: "Get reward history for user" })
  async getRewardHistory(
    @Param("userAddress") userAddress: string,
    @Query("page") page: number = 1,
    @Query("limit") limit: number = 10
  ) {
    return this.rewardService.getRewardHistory(userAddress, page, limit);
  }

  @Get("stats")
  @ApiOperation({ summary: "Get reward distribution statistics" })
  async getRewardStats() {
    return this.rewardService.getRewardStats();
  }

  @Post("calculate")
  @ApiOperation({ summary: "Calculate and update pending rewards" })
  @ApiBearerAuth()
  async calculateRewards() {
    return this.rewardService.calculateRewards();
  }

  @Get("apy/:poolId")
  @ApiOperation({ summary: "Get current APY for staking pool" })
  async getPoolAPY(@Param("poolId") poolId: string) {
    return this.rewardService.getPoolAPY(poolId);
  }
}