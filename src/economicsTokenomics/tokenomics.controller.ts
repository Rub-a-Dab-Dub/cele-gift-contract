
// economicsTokenomics/tokenomics.controller.ts
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
import { TokenomicsService } from "./tokenomics.service";
import { BurnTokensDto, DistributeFeesDto } from "./dto/tokenomics.dto";

@ApiTags("Tokenomics")
@Controller("tokenomics")
export class TokenomicsController {
  constructor(private readonly tokenomicsService: TokenomicsService) {}

  @Get("token-info")
  @ApiOperation({ summary: "Get CGIFT token information" })
  @ApiResponse({
    status: 200,
    description: "Token information retrieved successfully",
  })
  async getTokenInfo() {
    return this.tokenomicsService.getTokenInfo();
  }

  @Get("total-supply")
  @ApiOperation({ summary: "Get total token supply" })
  async getTotalSupply() {
    return this.tokenomicsService.getTotalSupply();
  }

  @Get("circulating-supply")
  @ApiOperation({ summary: "Get circulating token supply" })
  async getCirculatingSupply() {
    return this.tokenomicsService.getCirculatingSupply();
  }

  @Post("burn")
  @ApiOperation({ summary: "Burn tokens for deflationary pressure" })
  @ApiBearerAuth()
  async burnTokens(@Body() burnTokensDto: BurnTokensDto) {
    return this.tokenomicsService.burnTokens(burnTokensDto);
  }

  @Post("distribute-fees")
  @ApiOperation({ summary: "Distribute platform fees" })
  @ApiBearerAuth()
  async distributeFees(@Body() distributeFeesDto: DistributeFeesDto) {
    return this.tokenomicsService.distributeFees(distributeFeesDto);
  }

  @Get("fee-distribution-history")
  @ApiOperation({ summary: "Get fee distribution history" })
  async getFeeDistributionHistory(
    @Query("page") page: number = 1,
    @Query("limit") limit: number = 10
  ) {
    return this.tokenomicsService.getFeeDistributionHistory(page, limit);
  }

  @Get("burn-history")
  @ApiOperation({ summary: "Get token burn history" })
  async getBurnHistory(
    @Query("page") page: number = 1,
    @Query("limit") limit: number = 10
  ) {
    return this.tokenomicsService.getBurnHistory(page, limit);
  }
}