// economicsTokenomics/entities/staking-position.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity("staking_positions")
export class StakingPosition {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column()
  userAddress: string;

  @Column("decimal", { precision: 36, scale: 18 })
  stakedAmount: string;

  @Column("decimal", { precision: 36, scale: 18 })
  rewardDebt: string;

  @Column("decimal", { precision: 36, scale: 18 })
  pendingRewards: string;

  @Column()
  stakingPoolId: string;

  @Column("int")
  lockPeriod: number; // in days

  @Column()
  lockEndDate: Date;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}