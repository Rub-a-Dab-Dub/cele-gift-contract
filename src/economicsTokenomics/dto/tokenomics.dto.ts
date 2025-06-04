// economicsTokenomics/dto/tokenomics.dto.ts
import { IsString, IsNumber, IsPositive, IsOptional } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class BurnTokensDto {
  @ApiProperty({ description: "Amount to burn" })
  @IsString()
  amount: string;

  @ApiProperty({ description: "Burn reason" })
  @IsString()
  reason: string;
}

export class DistributeFeesDto {
  @ApiProperty({ description: "Total fees collected" })
  @IsString()
  totalFees: string;
}

export class LiquidityMiningDto {
  @ApiProperty({ description: "LP token amount" })
  @IsString()
  lpTokenAmount: string;

  @ApiProperty({ description: "Pool address" })
  @IsString()
  poolAddress: string;
}