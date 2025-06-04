// economicsTokenomics/entities/liquidity-position.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity("liquidity_positions")
export class LiquidityPosition {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column()
  userAddress: string;

  @Column()
  poolAddress: string;

  @Column("decimal", { precision: 36, scale: 18 })
  lpTokenAmount: string;

  @Column("decimal", { precision: 36, scale: 18 })
  rewardDebt: string;

  @Column("decimal", { precision: 36, scale: 18 })
  pendingRewards: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}