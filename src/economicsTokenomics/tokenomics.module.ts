// economicsTokenomics/tokenomics.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TokenomicsController } from './tokenomics.controller';
import { TokenomicsService } from './tokenomics.service';
import { StakingController } from './staking.controller';
import { StakingService } from './staking.service';
import { GovernanceController } from './governance.controller';
import { GovernanceService } from './governance.service';
import { RewardController } from './reward.controller';
import { RewardService } from './reward.service';
import { TokenService } from './token.service';
import { DeFiIntegrationService } from './defi-integration.service';
import { Token } from './entities/token.entity';
import { StakingPosition } from './entities/staking-position.entity';
import { GovernanceProposal } from './entities/governance-proposal.entity';
import { Vote } from './entities/vote.entity';
import { RewardDistribution } from './entities/reward-distribution.entity';
import { TokenBurn } from './entities/token-burn.entity';
import { LiquidityPosition } from './entities/liquidity-position.entity';
import { FeeDistribution } from './entities/fee-distribution.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Token,
      StakingPosition,
      GovernanceProposal,
      Vote,
      RewardDistribution,
      TokenBurn,
      LiquidityPosition,
      FeeDistribution,
    ]),
  ],
  controllers: [
    TokenomicsController,
    StakingController,
    GovernanceController,
    RewardController,
  ],
  providers: [
    TokenomicsService,
    StakingService,
    GovernanceService,
    RewardService,
    TokenService,
    DeFiIntegrationService,
  ],
  exports: [
    TokenomicsService,
    StakingService,
    GovernanceService,
    RewardService,
    TokenService,
    DeFiIntegrationService,
  ],
})
export class TokenomicsModule {}