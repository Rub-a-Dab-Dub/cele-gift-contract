// economicsTokenomics/staking.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
} from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from "@nestjs/swagger";
import { StakingService } from "./staking.service";
import {
  StakeTokensDto,
  UnstakeTokensDto,
  ClaimRewardsDto,
} from "./dto/staking.dto";

@ApiTags("Staking")
@Controller("staking")
export class StakingController {
  constructor(private readonly stakingService: StakingService) {}

  @Post("stake")
  @ApiOperation({ summary: "Stake CGIFT tokens" })
  @ApiBearerAuth()
  async stakeTokens(@Body() stakeTokensDto: StakeTokensDto) {
    return this.stakingService.stakeTokens(stakeTokensDto);
  }

  @Post("unstake")
  @ApiOperation({ summary: "Unstake CGIFT tokens" })
  @ApiBearerAuth()
  async unstakeTokens(@Body() unstakeTokensDto: UnstakeTokensDto) {
    return this.stakingService.unstakeTokens(unstakeTokensDto);
  }

  @Post("claim-rewards")
  @ApiOperation({ summary: "Claim staking rewards" })
  @ApiBearerAuth()
  async claimRewards(@Body() claimRewardsDto: ClaimRewardsDto) {
    return this.stakingService.claimRewards(claimRewardsDto);
  }

  @Get("positions/:userAddress")
  @ApiOperation({ summary: "Get user staking positions" })
  async getUserStakingPositions(@Param("userAddress") userAddress: string) {
    return this.stakingService.getUserStakingPositions(userAddress);
  }

  @Get("pools")
  @ApiOperation({ summary: "Get available staking pools" })
  async getStakingPools() {
    return this.stakingService.getStakingPools();
  }

  @Get("rewards/:userAddress")
  @ApiOperation({ summary: "Get pending rewards for user" })
  async getPendingRewards(@Param("userAddress") userAddress: string) {
    return this.stakingService.getPendingRewards(userAddress);
  }

  @Get("stats")
  @ApiOperation({ summary: "Get staking statistics" })
  async getStakingStats() {
    return this.stakingService.getStakingStats();
  }
}