// economicsTokenomics/dto/staking.dto.ts
import {
  IsString,
  IsNumber,
  IsPositive,
  IsOptional,
  IsBoolean,
} from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class StakeTokensDto {
  @ApiProperty({ description: "Amount to stake" })
  @IsString()
  amount: string;

  @ApiProperty({ description: "Staking pool ID" })
  @IsString()
  poolId: string;

  @ApiProperty({ description: "Lock period in days", required: false })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  lockPeriod?: number;
}

export class UnstakeTokensDto {
  @ApiProperty({ description: "Amount to unstake" })
  @IsString()
  amount: string;

  @ApiProperty({ description: "Staking position ID" })
  @IsString()
  positionId: string;
}

export class ClaimRewardsDto {
  @ApiProperty({ description: "Staking position ID" })
  @IsString()
  positionId: string;
}