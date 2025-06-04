// economicsTokenomics/tokenomics.service.ts
import { Injectable, BadRequestException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Token } from "./entities/token.entity";
import { TokenBurn } from "./entities/token-burn.entity";
import { FeeDistribution } from "./entities/fee-distribution.entity";
import { BurnTokensDto, DistributeFeesDto } from "./dto/tokenomics.dto";
import { ethers } from "ethers";

@Injectable()
export class TokenomicsService {
  constructor(
    @InjectRepository(Token)
    private tokenRepository: Repository<Token>,
    @InjectRepository(TokenBurn)
    private tokenBurnRepository: Repository<TokenBurn>,
    @InjectRepository(FeeDistribution)
    private feeDistributionRepository: Repository<FeeDistribution>
  ) {}

  async getTokenInfo() {
    const token = await this.tokenRepository.findOne({
      where: { symbol: "CGIFT" },
    });
    if (!token) {
      throw new BadRequestException("CGIFT token not found");
    }
    return token;
  }

  async getTotalSupply() {
    const token = await this.getTokenInfo();
    return { totalSupply: token.totalSupply };
  }

  async getCirculatingSupply() {
    const token = await this.getTokenInfo();
    return { circulatingSupply: token.circulatingSupply };
  }

  async burnTokens(burnTokensDto: BurnTokensDto) {
    const { amount, reason } = burnTokensDto;

    // Validate amount
    if (!ethers.utils.isAddress(amount) && isNaN(parseFloat(amount))) {
      throw new BadRequestException("Invalid amount format");
    }

    const token = await this.getTokenInfo();
    const burnAmount = ethers.BigNumber.from(ethers.utils.parseEther(amount));
    const currentSupply = ethers.BigNumber.from(
      ethers.utils.parseEther(token.totalSupply)
    );

    if (burnAmount.gt(currentSupply)) {
      throw new BadRequestException("Burn amount exceeds total supply");
    }

    // Update token supply
    const newTotalSupply = currentSupply.sub(burnAmount);
    const newCirculatingSupply = ethers.BigNumber.from(
      ethers.utils.parseEther(token.circulatingSupply)
    ).sub(burnAmount);
    const newBurnedAmount = ethers.BigNumber.from(
      ethers.utils.parseEther(token.burnedAmount)
    ).add(burnAmount);

    await this.tokenRepository.update(token.id, {
      totalSupply: ethers.utils.formatEther(newTotalSupply),
      circulatingSupply: ethers.utils.formatEther(newCirculatingSupply),
      burnedAmount: ethers.utils.formatEther(newBurnedAmount),
    });

    // Record burn event
    const tokenBurn = this.tokenBurnRepository.create({
      amount,
      reason,
      transactionHash: ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(`burn-${Date.now()}`)
      ),
      burnedBy: "system", // In real implementation, get from authenticated user
    });

    await this.tokenBurnRepository.save(tokenBurn);

    return {
      success: true,
      burnedAmount: amount,
      newTotalSupply: ethers.utils.formatEther(newTotalSupply),
      transactionHash: tokenBurn.transactionHash,
    };
  }

  async distributeFees(distributeFeesDto: DistributeFeesDto) {
    const { totalFees } = distributeFeesDto;

    const totalFeesAmount = ethers.utils.parseEther(totalFees);

    // Fee distribution percentages
    const stakingRewardsPercent = 40; // 40%
    const liquidityRewardsPercent = 30; // 30%
    const burnPercent = 20; // 20%
    const treasuryPercent = 10; // 10%

    const stakingRewards = totalFeesAmount.mul(stakingRewardsPercent).div(100);
    const liquidityRewards = totalFeesAmount
      .mul(liquidityRewardsPercent)
      .div(100);
    const burnAmount = totalFeesAmount.mul(burnPercent).div(100);
    const treasuryAmount = totalFeesAmount.mul(treasuryPercent).div(100);

    const feeDistribution = this.feeDistributionRepository.create({
      totalFees,
      stakingRewards: ethers.utils.formatEther(stakingRewards),
      liquidityRewards: ethers.utils.formatEther(liquidityRewards),
      burnAmount: ethers.utils.formatEther(burnAmount),
      treasuryAmount: ethers.utils.formatEther(treasuryAmount),
      transactionHash: ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(`fee-dist-${Date.now()}`)
      ),
    });

    await this.feeDistributionRepository.save(feeDistribution);

    // Auto-burn the burn portion
    await this.burnTokens({
      amount: ethers.utils.formatEther(burnAmount),
      reason: "Automatic fee burn",
    });

    return {
      success: true,
      distribution: feeDistribution,
    };
  }

  async getFeeDistributionHistory(page: number, limit: number) {
    const [distributions, total] =
      await this.feeDistributionRepository.findAndCount({
        order: { createdAt: "DESC" },
        skip: (page - 1) * limit,
        take: limit,
      });

    return {
      distributions,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getBurnHistory(page: number, limit: number) {
    const [burns, total] = await this.tokenBurnRepository.findAndCount({
      order: { createdAt: "DESC" },
      skip: (page - 1) * limit,
      take: limit,
    });

    return {
      burns,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}